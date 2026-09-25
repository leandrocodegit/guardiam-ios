//
//  Formatter.swift
//  OwnTracks
//
//  Created by Christoph Krey on 11/07/2026.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation

class OwnTracksFormatter {
    
    class func pressure(from pressure: Double) -> String {
        let m = Measurement(value: pressure, unit: UnitPressure.kilopascals);
        if Locale.current.measurementSystem == .metric {
            return m.formatted(.measurement(width: .narrow, usage: .barometric, numberFormatStyle: .number.grouping(.never) ));
        } else {
            return m.formatted(.measurement(width: .narrow, usage: .barometric, numberFormatStyle: .number.precision(.fractionLength(2))));
        }
    }
    
    class func distance(from distance: CLLocationDistance) -> String {
        let m = Measurement(value: distance, unit: UnitLength.meters);
        return m.formatted(.measurement(width: .narrow, usage: .road));
    }

    class func accuracy(from accuracy: CLLocationAccuracy) -> String {
        if accuracy <= 0 {
            return "-";
        } else {
            let m = Measurement(value: accuracy, unit: UnitLength.meters);
            return "±" + m.formatted(.measurement(width: .narrow, usage: .road));
        }
    }
    
    class func coordinate(from location: CLLocation) -> String {
        if CLLocationCoordinate2DIsValid(location.coordinate) {
            let mlat = Measurement(value: location.coordinate.latitude, unit: UnitAngle.degrees);
            let mlon = Measurement(value: location.coordinate.longitude, unit: UnitAngle.degrees);

            return mlat.formatted(.measurement(width: .narrow, usage: .asProvided)) + "," + mlon.formatted(.measurement(width: .narrow, usage: .asProvided)) + " (" +
            OwnTracksFormatter.accuracy(from: location.horizontalAccuracy) + ")";
        } else {
            return "-";
        }
    }
    
    class func altitude(from location: CLLocation) -> String {
        if location.altitude <= 0 {
            return "-"
        } else {
            let alt = Measurement(value: location.altitude, unit: UnitLength.meters);            
            return "✈︎" + alt.formatted(.measurement(width: .narrow, usage: .general)) +
            " (" + accuracy(from: location.verticalAccuracy) + ")";
        }
    }
    
    class func speed(from location: CLLocation) -> String {
        if location.speed < 0 {
            return "-"
        } else {
            let speed = Measurement(value: location.speed, unit: UnitSpeed.kilometersPerHour);
            return speed.formatted(.measurement(width: .narrow,
                                                usage: .general,
                                                numberFormatStyle: .number .precision(.fractionLength(0))));
        }
    }
    
    class func cog(from location: CLLocation) -> String {
        if location.course < 0 {
            return "-"
        } else {
            let course = Measurement(value: location.course, unit: UnitAngle.degrees);
            return course.formatted(.measurement(width: .narrow,
                                                 usage: .general,
                                                 numberFormatStyle: .number .precision(.fractionLength(0))));

        }
    }
    
    class func timestamp(from date: Date?) -> String {
        if date == nil {
            return "-";
        } else {
            return date!.formatted(date: .numeric, time: .standard);
        }
    }
}
