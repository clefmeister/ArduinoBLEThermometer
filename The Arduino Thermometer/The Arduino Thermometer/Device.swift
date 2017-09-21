//
//  Device.swift
//  The Arduino Thermometer
//
//  Created by Jeff Butts on 8/20/17.
//  Copyright © 2017 Jeff Butts. All rights reserved.
//

import Foundation

struct Device {
    static let WeatherSensorsAdvertisingUUID = "0000008A-0000-1000-8000-0026BB765291"
    
    static let WeatherServiceUUID = "0000008A-0000-1000-8000-0026BB765291"
    static let TemperatureDataUUID = "00000011-0000-1000-8000-0026BB765291"
    static let HumidityDataUUID = "00000010-0000-1000-8000-0026BB765291"
    
    static let SensorDataIndexTempAbient = 0
    static let SensorDataIndexHumidity = 0
}
