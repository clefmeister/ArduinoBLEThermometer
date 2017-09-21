//
//  ViewController.swift
//  The Arduino Thermometer
//
//  Created by Jeff Butts on 8/20/17.
//  Copyright © 2017 Jeff Butts. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var controlContainerView: UIView!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var circleView: UIView!
    
    // Scanning interval times
    let timerPauseInterval:TimeInterval = 10.0
    let timerScanInterval:TimeInterval = 2.0
    
    // UI-related variables
    let temperatureLabelFontName = "Didot"
    let temperatureLabelFontSizeMessage:CGFloat = 36.0
    let temperatureLabelFontSizeTemp:CGFloat = 56.0
    var circleDrawn = false
    
    var lastTemperatureTens = 0
    let defaultInitialTemperature:Double = -9999
    var lastTemperature:Double = 0.0
    var lastHumidity:Double = -9999
    var keepScanning = false
    
    // Core Bluetooth properties
    var centralManager:CBCentralManager!
    var weatherSensors:CBPeripheral?
    var temperatureCharacteristic:CBCharacteristic?
    var humidityCharacteristic:CBCharacteristic?
    
    let weatherSensorsName = "ArduinoThermometer"
    
    lazy var weatherData: NSData = NSData()
    let urlPath: String = "http://api.wunderground.com/api/6adb8715c3abc005/conditions/q/OH/Canfield.json"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lastTemperature = defaultInitialTemperature
        
        // Create CBCentral Manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Configure initial UI
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Searching"
        humidityLabel.text = ""
        humidityLabel.isHidden = true
        getCurrentConditions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if lastTemperature != defaultInitialTemperature {
            updateTemperatureDisplay()
        }
    }
    
    // Bluetooth scanning
    
    @objc func pauseScan() {
        // Scanning uses up battery on phone, so pause the scan process for the designated interval.
        _ = Timer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
        centralManager.stopScan()
        disconnectButton.isEnabled = true
    }
    
    @objc func resumeScan() {
        if keepScanning {
            // Start scanning again...
            disconnectButton.isEnabled = false
            temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
            temperatureLabel.text = "Searching"
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            let weatherSensorsAdvertisingUUID = CBUUID(string: Device.WeatherSensorsAdvertisingUUID)
            centralManager.scanForPeripherals(withServices: [weatherSensorsAdvertisingUUID], options: nil)
        } else {
            disconnectButton.isEnabled = true
        }
    }
    
    // Updating UI
    
    func updateTemperatureDisplay() {
        if !circleDrawn {
            drawCircle()
        } else {
            circleView.isHidden = false
        }
        
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeTemp)
        temperatureLabel.text = " \(lastTemperature)º"
    }

    func drawCircle() {
        circleView.isHidden = false
        //let circleLayer = CAShapeLayer()
        // let rectForCircle = CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: circleView.frame.width, height: circleView.frame.height))
        //circleLayer.path = UIBezierPath(ovalIn: circleView.bounds) as! CGPath
        //circleView.layer.addSublayer(circleLayer)
        //circleLayer.lineWidth = 2
        //circleLayer.strokeColor = UIColor.white.cgColor
        //circleLayer.fillColor = UIColor.clear.cgColor
        
        let width: CGFloat = circleView.frame.width
        let height: CGFloat = circleView.frame.height
        
        let circleLayer = CAShapeLayer()
        circleLayer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height)).cgPath
        circleLayer.lineWidth = 2
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.fillColor = UIColor.clear.cgColor
        circleView.layer.addSublayer(circleLayer)
        circleDrawn = true
    }
    
    func displayTemperature(data:NSData) {
        // We get back 4 bytes of data, so we'll convert it and display it
        let dataLength = data.length / MemoryLayout<UInt16>.size
        var dataArray = [Float](repeating: 0, count:dataLength)
        data.getBytes(&dataArray, length: dataLength * MemoryLayout<Int16>.size)
        
        let rawAmbientTemp:Float = dataArray[Device.SensorDataIndexTempAbient]
        let ambientTempC = Float(rawAmbientTemp)
        let ambientTempF = convertCelsiusToFahrenheit(celsius: ambientTempC)
        
        let temp = Int(ambientTempF)
        lastTemperature = Double(temp)
        
        if UIApplication.shared.applicationState == .active {
            updateTemperatureDisplay()
        }
    }
    
    func displayHumidity(data:NSData) {
        let dataLength = data.length / MemoryLayout<UInt16>.size
        var dataArray = [Float](repeating: 0, count:dataLength)
        data.getBytes(&dataArray, length: dataLength * MemoryLayout<Int16>.size)
        
        let rawHumidity:Float = dataArray[Device.SensorDataIndexHumidity]
        let relativeHumidity = Float(rawHumidity)
        
        humidityLabel.text = String(format: " Humidity: %.01f%%", relativeHumidity)
        humidityLabel.isHidden = false
    }
    
    // User interaction
    

    @IBAction func handleDisconnectButtonTapped(_ sender: AnyObject) {
        // If we don't have a weather sensor device, start scanning for one
        if weatherSensors == nil {
            keepScanning = true
            resumeScan()
            return
        } else {
            disconnect()
        }
    }
    
    func disconnect() {
        if let weatherSensors = self.weatherSensors {
            if let tc = self.temperatureCharacteristic {
                weatherSensors.setNotifyValue(false, for: tc)
            }
            if let hc = self.humidityCharacteristic {
                weatherSensors.setNotifyValue(false, for: hc)
            }
            
            centralManager.cancelPeripheralConnection(weatherSensors)
        }
        
        temperatureCharacteristic = nil
        humidityCharacteristic = nil
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var showAlert = true
        var message = ""
        
        switch central.state {
        case .poweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .unknown:
            message = "The state of the BLE Manager is unknown."
        case .poweredOn:
            showAlert = false
            message = "Bluetooth LE is turned on and ready for communication."
            
            print(message)
            keepScanning = true
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            
            // Initiate Scan for Peripherals
            //Option 1: Scan for all devices
            // centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            // Option 2: Scan for devices that have the service you're interested in...
            //let weatherSensorsAdvertisingUUID = CBUUID(string: "E959CD3E-BA91-3821-0247-A0D4FC19CCC3")
            let weatherSensorsAdvertisingUUID = CBUUID(string: Device.WeatherSensorsAdvertisingUUID)
            centralManager.scanForPeripherals(withServices: [weatherSensorsAdvertisingUUID], options: nil)

        }
        
        if showAlert {
            let alertController = UIAlertController(title: "Central Manager State", message: message, preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil)
            alertController.addAction(okAction)
            self.show(alertController, sender: self)
        }
    }

    // Run this when central manager discovers a peripheral while scanning
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("centralManager didDiscoverPeripheral - CBAdvertisementDataLocalNameKey is \"\(CBAdvertisementDataLocalNameKey)\"")
        
        // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("NEXT PERIPHERAL NAME: \(peripheralName)")
            print("NEXT PERIPHERAL UUID: \(peripheral.identifier.uuid)")
            
            if peripheralName == weatherSensorsName {
                print("*** WEATHER SENSORS FOUND! ADDING NOW ***")
                // to save power, stop scanning for other devices
                keepScanning = false
                disconnectButton.isEnabled = true
                
                // save a reference to the sensor tag
                weatherSensors = peripheral
                weatherSensors!.delegate = self
                
                // Request a connection to the peripheral
                centralManager.connect(weatherSensors!, options: nil)
            }
        }
    }
    
    // Run this when connection established
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*** SUCCESSFULLY CONNECTED TO WEATHER SENSORS ***")
        
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Connected"
        
        // Now that we've successfully connected to the SensorTag, let's discover the services.
        // - NOTE:  we pass nil here to request ALL services be discovered.
        //          If there was a subset of services we were interested in, we could pass the UUIDs here.
        //          Doing so saves battery life and saves time.
        peripheral.discoverServices(nil)
    }
    
    // This guy runs when the CM can't connect to a peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("*** CONNECTION TO WEATHER SENSORS FAILED ***")
    }
    
    // And now for one when we disconnect a peripheral
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("*** DISCONNECTED FROM WEATHER SENSORS ***")
        lastTemperature = 0
        circleView.isHidden = true
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Tap to search"
        humidityLabel.text = ""
        humidityLabel.isHidden = true
        if error != nil {
            print("*** DISCONNECTION DETAILS: \(error!.localizedDescription) ***")
        }
        weatherSensors = nil
    }
    
    // CBPeripheralDelegate methods
    
    // Invoked when discovering peripheral's available services, when app calls discoverServices: method
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("*** ERROR DISCOVERING SERVICES: \(error?.localizedDescription) ***")
            return
        }
        
        // Core Bluetooth creates an array of CBService objects, one for each service discovered on the peripheral
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                
                // Now, if we discovered the temperature or humidity service, discover the characteristics of those services
                if (service.uuid == CBUUID(string:Device.WeatherServiceUUID)) {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(error?.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            var enableValue:UInt8 = 1
            let enableBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)
            
            for characteristic in characteristics {
                // Temperature Data Characteristic
                if characteristic.uuid == CBUUID(string: Device.TemperatureDataUUID) {
                    // Enable temperature sensor notifications
                    temperatureCharacteristic = characteristic
                    weatherSensors?.setNotifyValue(true, for: characteristic)
                }
                
                // Humidity Data Characteristic
                if characteristic.uuid == CBUUID(string: Device.HumidityDataUUID) {
                    humidityCharacteristic = characteristic
                    weatherSensors?.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    // When the app retrieves a characteristic's value, invoke this
    // This is what actually pulls in the data and sends it off to be displayed
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("ERROR UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(error?.localizedDescription) ***")
        }
        
        // Extract data from the characteristic's value property and display it
        if let dataBytes = characteristic.value {
            if characteristic.uuid == CBUUID(string: Device.TemperatureDataUUID) {
                displayTemperature(data: dataBytes as NSData)
            } else if characteristic.uuid == CBUUID(string: Device.HumidityDataUUID) {
                displayHumidity(data: dataBytes as NSData)
            }
        }
    }
    
    func getCurrentConditions() {
        let url: URL = URL(string: urlPath)!
        let session = URLSession.shared

        let task = session.dataTask(with: url) {data, response, error in
            if let error = error {
                print("Failed to download data: \(error)")
            } else if let data = data {
                print("Data downloaded")
                self.weatherData = data as NSData
                print(self.weatherData)
                self.parseJSON(inputData: data as NSData)
            } else {
                print("Something is wrong ...")
            }
        }
        task.resume()
    }
    
    func parseJSON(inputData: NSData) {
                    struct current_observation: Codable {
                        let title: String
                        let weather: String
                        let temp_f: Float
                        let relative_humidity: String
                        let dewpoint_f: Int
        }

        let jsonData = weatherData
        let decoder = JSONDecoder()
        let currentWeather = try! decoder.decode([current_observation].self, from: jsonData as Data)
        print(currentWeather)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Various other methods
    func convertCelsiusToFahrenheit(celsius:Float) -> Double {
        let fahrenheit = (celsius * 1.8) + Float(32.0)
        return Double(fahrenheit)
    }

}

