//
//  StoreKitManager.swift
//  OwnTracks
//
//  Gerenciador de Assinaturas In-App usando StoreKit 2 (iOS 15+).
//  Sincroniza transações com a App Store e vincula o appAccountToken
//  ao userId do Keycloak para o webhook backend (ms-pagamento).
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
@objc class StoreKitManager: NSObject {

    @objc static let shared = StoreKitManager()

    @objc static let defaultSubscriptionIds: [String] = [
        "2_start",
        "2_quantity",
        "2_super",
        "plano_start",
        "plano_quantity",
        "plano_super",
        "subscription_monthly",
        "start",
        "quantity",
        "super"
    ]

    private(set) var availableProducts: [Product] = []
    private(set) var activeTransactions: [Transaction] = []
    private var updatesTask: Task<Void, Never>? = nil

    private override init() {
        super.init()
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Carregamento de Produtos

    /// Carrega os produtos de assinatura configurados no App Store Connect
    @objc func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: StoreKitManager.defaultSubscriptionIds)
            self.availableProducts = storeProducts
            if storeProducts.isEmpty {
                print("[StoreKitManager] ⚠️ ATENÇÃO: App Store retornou 0 produtos. Verifique:")
                print("[StoreKitManager]   1. Os produtos estão em 'Prepare for Submission' (não disponíveis ainda)")
                print("[StoreKitManager]   2. O Bundle ID do app corresponde ao app no App Store Connect")
                print("[StoreKitManager]   3. Uma build foi submetida e associada aos produtos")
                print("[StoreKitManager]   IDs buscados: \(StoreKitManager.defaultSubscriptionIds)")
            } else {
                print("[StoreKitManager] ✅ Carregados \(storeProducts.count) produtos da App Store:")
                storeProducts.forEach { print("[StoreKitManager]   - id: \($0.id) | displayName: \($0.displayName)") }
            }
        } catch {
            print("[StoreKitManager] ❌ Erro ao carregar produtos da App Store: \(error.localizedDescription)")
        }
    }

    /// Atualiza a lista de transações e direitos ativos do usuário
    @objc func updatePurchasedProducts() async {
        var activeList: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    activeList.append(transaction)
                }
            } catch {
                print("[StoreKitManager] Erro ao verificar entitlement: \(error.localizedDescription)")
            }
        }
        self.activeTransactions = activeList
    }

    // MARK: - Listener de Transações em Tempo Real

    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("[StoreKitManager] Transação não verificada: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Compras e Restauração

    /// Inicia o fluxo de compra da assinatura
    @objc func purchasePlan(_ planId: String, completion: @escaping (Bool, String?) -> Void) {
        Task { @MainActor in
            let targetId = planId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            print("[StoreKitManager] 🔍 Buscando produto: '\(targetId)' | Disponíveis: \(availableProducts.map { $0.id })")

            var product = availableProducts.first { $0.id.lowercased() == targetId }
            if product == nil {
                product = availableProducts.first { $0.id.lowercased().contains(targetId) }
            }
            if product == nil {
                print("[StoreKitManager] 🔄 Produto não encontrado em cache, recarregando da App Store...")
                await loadProducts()
                print("[StoreKitManager] 🔍 Após reload, disponíveis: \(availableProducts.map { $0.id })")
                product = availableProducts.first { $0.id.lowercased() == targetId }
                    ?? availableProducts.first { $0.id.lowercased().contains(targetId) }
                    ?? availableProducts.first
            }

            guard let productToPurchase = product else {
                let available = availableProducts.isEmpty ? "nenhum (App Store retornou 0 produtos - verifique status no App Store Connect)" : availableProducts.map { $0.id }.joined(separator: ", ")
                let msg = "Plano '\(planId)' não encontrado. Produtos disponíveis: \(available)"
                print("[StoreKitManager] ❌ \(msg)")
                completion(false, msg)
                return
            }

            do {
                var options: Set<Product.PurchaseOption> = []

                // Associa o userId do usuário atual como appAccountToken (UUID) para o webhook do ms-pagamento
                if let userIdStr = AuthManager.shared.getUserId(),
                   let userUUID = UUID(uuidString: userIdStr) {
                    options.insert(.appAccountToken(userUUID))
                    print("[StoreKitManager] appAccountToken vinculado: \(userIdStr)")
                } else {
                    print("[StoreKitManager] Aviso: userId do Keycloak não foi obtido como UUID válido.")
                }

                let result = try await productToPurchase.purchase(options: options)

                switch result {
                case .success(let verification):
                    let transaction = try self.checkVerified(verification)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                    print("[StoreKitManager] Compra realizada com sucesso! TransactionId: \(transaction.id)")
                    completion(true, nil)

                case .userCancelled:
                    print("[StoreKitManager] Compra cancelada pelo usuário.")
                    completion(false, "Compra cancelada pelo usuário.")

                case .pending:
                    print("[StoreKitManager] Compra pendente de autorização externa/pais.")
                    completion(false, "Compra pendente de aprovação.")

                @unknown default:
                    completion(false, "Resultado de compra desconhecido.")
                }
            } catch {
                print("[StoreKitManager] Erro no fluxo de compra: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }

    /// Restaura transações anteriores com AppStore.sync()
    @objc func restorePurchases(completion: @escaping (Bool, String?) -> Void) {
        Task { @MainActor in
            do {
                try await AppStore.sync()
                await self.updatePurchasedProducts()
                print("[StoreKitManager] Compras restauradas e sincronizadas com sucesso.")
                completion(true, nil)
            } catch {
                print("[StoreKitManager] Erro ao restaurar compras: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }

    // MARK: - Estado em JSON para WebView JS Bridge

    /// Retorna um JSON representando o status atual da assinatura
    @objc func getSubscriptionStatusJSON() -> String {
        let isSubscribed = !activeTransactions.isEmpty
        let activeTx = activeTransactions.first

        var dict: [String: Any] = [
            "isSubscribed": isSubscribed,
            "isConnected": true,
            "productId": activeTx?.productID ?? "",
            "originalTransactionId": activeTx?.originalID.description ?? "",
            "transactionId": activeTx?.id.description ?? ""
        ]

        if let expirationDate = activeTx?.expirationDate {
            dict["expirationTime"] = Int64(expirationDate.timeIntervalSince1970 * 1000)
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }

        return "{\"isSubscribed\":false,\"isConnected\":true}"
    }
}
