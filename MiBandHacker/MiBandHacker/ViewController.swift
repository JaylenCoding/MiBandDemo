//
//  ViewController.swift
//  MiBandHacker
//
//  Created by Minecode on 2017/6/7.
//  Copyright © 2017年 minecode.org. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // macro
    let STEP = "FF06"
    let BATTERY = "FF0C"
    let VIBRATE = "2A06"
    let DEVICE = "FF01"
    
    // UI Widget
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var vibrateButton: UIButton!
    @IBOutlet weak var stopVibrateButton: UIButton!
    @IBOutlet weak var loadingInd: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var resultField: UITextView!
    
    // Data controller
    var theManager: CBCentralManager!
    var thePerpher: CBPeripheral!
    var theVibrator: CBCharacteristic!
    
    // Data Saver
    var isDisconnected = true
    var isVibrating = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        theManager = CBCentralManager.init(delegate: self as? CBCentralManagerDelegate, queue: nil)
        self.scanButton.isEnabled = false
        statusLabel.text = ""
        loadingInd.isHidden = true
    }
    
    // 扫描并连接
    @IBAction func startConnectAction(_ sender: UIButton) {
        switch theManager.state {
        case .poweredOn:
            statusLabel.text = "正在扫描…"
            theManager.scanForPeripherals(withServices: nil, options: nil)
            self.loadingInd.startAnimating()
            self.scanButton.isEnabled = false
            self.isDisconnected = false
        default:
            break
        }
    }
    
    @IBAction func disconnectAction(_ sender: UIButton) {
        if ((thePerpher) != nil) {
            theManager.cancelPeripheralConnection(thePerpher)
            thePerpher = nil
            theVibrator = nil
            statusLabel.text = "设备已断开"
            scanButton.isEnabled = true
            isDisconnected = true
            isVibrating = false
        }
    }
    
    @IBAction func vibrateAction(_ sender: Any) {
        if ((thePerpher != nil) && (theVibrator != nil)) {
            let data: [UInt8] = [UInt8.init(2)];
            let theData: Data = Data.init(bytes: data)
            thePerpher.writeValue(theData, for: theVibrator, type: CBCharacteristicWriteType.withoutResponse)
        }
    }
    
    @IBAction func stopVibrateAction(_ sender: UIButton) {
        if ((thePerpher != nil) && (theVibrator != nil)) {
            let data: [UInt8] = [UInt8.init(0)];
            let theData: Data = Data.init(bytes: data)
            thePerpher.writeValue(theData, for: theVibrator, type: CBCharacteristicWriteType.withoutResponse)
            isVibrating = false
        }
    }
    
    
    // 处理当前蓝牙主设备状态
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusLabel.text = "蓝牙已开启"
            self.scanButton.isEnabled = true
        default:
            statusLabel.text = "蓝牙未开启！"
            self.loadingInd.stopAnimating()
        }
    }
    
    // 扫描到设备
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (peripheral.name?.hasSuffix("MI"))! {
            thePerpher = peripheral
            central.stopScan()
            central.connect(peripheral, options: nil)
            statusLabel.text = "搜索成功，开始连接"
            
        }
        // 特征值匹配请用 peripheral.identifier.uuidString
        resultField.text = String.init(format: "发现手环\n名称：%@\nUUID：%@\n", peripheral.name!, peripheral.identifier.uuidString)
    }
    
    // 成功连接到设备
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusLabel.text = "连接成功，正在扫描信息..."
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    // 连接到设备失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        loadingInd.stopAnimating()
        statusLabel.text = "连接设备失败"
        scanButton.isEnabled = true
    }
    
    // 扫描服务
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if ((error) != nil) {
            statusLabel.text = "查找服务失败"
            loadingInd.stopAnimating()
            scanButton.isEnabled = true
            return
        }
        else {
            for service in peripheral.services! {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    // 扫描到特征值
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if ((error) != nil) {
            statusLabel.text = "查找服务失败"
            loadingInd.stopAnimating()
            scanButton.isEnabled = true
            return
        }
        else {
            for characteristic in service.characteristics! {
                peripheral.setNotifyValue(true, for: characteristic)
                
                if (characteristic.uuid.uuidString == BATTERY) {
                    peripheral.readValue(for: characteristic)
                }
                else if (characteristic.uuid.uuidString == DEVICE) {
                    peripheral.readValue(for: characteristic)
                }
                else if (characteristic.uuid.uuidString == VIBRATE) {
                    theVibrator = characteristic
                }
            }
        }
    }
    
    // 扫描到具体设备
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if ((error) != nil) {
            statusLabel.text = "从设备获取值失败"
            return
        }
        else {
            if(characteristic.uuid.uuidString == BATTERY) {
                var batteryBytes = [UInt8](characteristic.value!)
                var batteryVal:Int = Int.init(batteryBytes[0])
                self.resultField.text = String.init(format: "%@电量：%d%%\n", resultField.text, batteryVal)
            }
            loadingInd.stopAnimating()
            scanButton.isEnabled = true
            statusLabel.text = "信息扫描完成！"
            if (isVibrating) {
                vibrateAction(Any)
            }
        }
    }
    
    // 与设备断开连接
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusLabel.text = "设备已断开"
        scanButton.isEnabled = true
        if(!isDisconnected) {
            theManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    
}

