import Darwin
import Foundation

struct DeviceLibrary {
  // MARK: - 識別子から機種名（日本語）
  static let deviceNamesJa: [String: String] = [
    // iPhone
    "iPhone8,1": "iPhone 6s",
    "iPhone8,2": "iPhone 6s Plus",
    "iPhone8,4": "iPhone SE (第1世代)",
    "iPhone9,1": "iPhone 7",
    "iPhone9,3": "iPhone 7",
    "iPhone9,2": "iPhone 7 Plus",
    "iPhone9,4": "iPhone 7 Plus",
    "iPhone10,1": "iPhone 8",
    "iPhone10,4": "iPhone 8",
    "iPhone10,2": "iPhone 8 Plus",
    "iPhone10,5": "iPhone 8 Plus",
    "iPhone10,3": "iPhone X",
    "iPhone10,6": "iPhone X",
    "iPhone11,8": "iPhone XR",
    "iPhone11,2": "iPhone XS",
    "iPhone11,4": "iPhone XS Max",
    "iPhone11,6": "iPhone XS Max",
    "iPhone12,1": "iPhone 11",
    "iPhone12,3": "iPhone 11 Pro",
    "iPhone12,5": "iPhone 11 Pro Max",
    "iPhone12,8": "iPhone SE (第2世代)",
    "iPhone13,1": "iPhone 12 mini",
    "iPhone13,2": "iPhone 12",
    "iPhone13,3": "iPhone 12 Pro",
    "iPhone13,4": "iPhone 12 Pro Max",
    "iPhone14,4": "iPhone 13 mini",
    "iPhone14,5": "iPhone 13",
    "iPhone14,2": "iPhone 13 Pro",
    "iPhone14,3": "iPhone 13 Pro Max",
    "iPhone14,6": "iPhone SE (第3世代)",
    "iPhone14,7": "iPhone 14",
    "iPhone14,8": "iPhone 14 Plus",
    "iPhone15,2": "iPhone 14 Pro",
    "iPhone15,3": "iPhone 14 Pro Max",
    "iPhone15,4": "iPhone 15",
    "iPhone15,5": "iPhone 15 Plus",
    "iPhone16,1": "iPhone 15 Pro",
    "iPhone16,2": "iPhone 15 Pro Max",
    "iPhone17,1": "iPhone 16 Pro",
    "iPhone17,2": "iPhone 16 Pro Max",
    "iPhone17,3": "iPhone 16",
    "iPhone17,4": "iPhone 16 Plus",
    "iPhone17,5": "iPhone 16e",
    "iPhone18,1": "iPhone 17 Pro",
    "iPhone18,2": "iPhone 17 Pro Max",
    "iPhone18,3": "iPhone 17",
    "iPhone18,4": "iPhone Air",
    "iPhone18,5": "iPhone 17e",
    "iPhone19,2": "iPhone 18 Pro",
    "iPhone19,3": "iPhone 18 Pro Max",
    "iPhone19,4": "iPhone Duo",
    "iPhone19,7": "iPhone 18 Pro Max",

    // iPad
    "iPad4,1": "iPad Air (第1世代)",
    "iPad4,2": "iPad Air (第1世代)",
    "iPad4,3": "iPad Air (第1世代)",
    "iPad5,1": "iPad mini (第4世代)",
    "iPad5,2": "iPad mini (第4世代)",
    "iPad5,3": "iPad Air (第2世代)",
    "iPad5,4": "iPad Air (第2世代)",
    "iPad6,3": "iPad Pro 9.7",
    "iPad6,4": "iPad Pro 9.7",
    "iPad6,7": "iPad Pro 12.9 (第1世代)",
    "iPad6,8": "iPad Pro 12.9 (第1世代)",
    "iPad6,11": "iPad (第5世代)",
    "iPad6,12": "iPad (第5世代)",
    "iPad7,1": "iPad Pro 12.9 (第2世代)",
    "iPad7,2": "iPad Pro 12.9 (第2世代)",
    "iPad7,3": "iPad Pro 10.5",
    "iPad7,4": "iPad Pro 10.5",
    "iPad7,5": "iPad (第6世代)",
    "iPad7,6": "iPad (第6世代)",
    "iPad7,11": "iPad (第7世代)",
    "iPad7,12": "iPad (第7世代)",
    "iPad8,1": "iPad Pro 11 (第1世代)",
    "iPad8,2": "iPad Pro 11 (第1世代)",
    "iPad8,3": "iPad Pro 11 (第1世代)",
    "iPad8,4": "iPad Pro 11 (第1世代)",
    "iPad8,5": "iPad Pro 12.9 (第3世代)",
    "iPad8,6": "iPad Pro 12.9 (第3世代)",
    "iPad8,7": "iPad Pro 12.9 (第3世代)",
    "iPad8,8": "iPad Pro 12.9 (第3世代)",
    "iPad8,9": "iPad Pro 11 (第2世代)",
    "iPad8,10": "iPad Pro 11 (第2世代)",
    "iPad8,11": "iPad Pro 12.9 (第4世代)",
    "iPad8,12": "iPad Pro 12.9 (第4世代)",
    "iPad11,1": "iPad mini (第5世代)",
    "iPad11,2": "iPad mini (第5世代)",
    "iPad11,3": "iPad Air (第3世代)",
    "iPad11,4": "iPad Air (第3世代)",
    "iPad11,6": "iPad (第8世代)",
    "iPad11,7": "iPad (第8世代)",
    "iPad12,1": "iPad (第9世代)",
    "iPad12,2": "iPad (第9世代)",
    "iPad13,1": "iPad Air (第4世代)",
    "iPad13,2": "iPad Air (第4世代)",
    "iPad13,4": "iPad Pro 11 (第3世代)",
    "iPad13,5": "iPad Pro 11 (第3世代)",
    "iPad13,6": "iPad Pro 11 (第3世代)",
    "iPad13,7": "iPad Pro 11 (第3世代)",
    "iPad13,8": "iPad Pro 12.9 (第5世代)",
    "iPad13,9": "iPad Pro 12.9 (第5世代)",
    "iPad13,10": "iPad Pro 12.9 (第5世代)",
    "iPad13,11": "iPad Pro 12.9 (第5世代)",
    "iPad13,16": "iPad Air (第5世代)",
    "iPad13,17": "iPad Air (第5世代)",
    "iPad13,18": "iPad (第10世代)",
    "iPad13,19": "iPad (第10世代)",
    "iPad14,1": "iPad mini (第6世代)",
    "iPad14,2": "iPad mini (第6世代)",
    "iPad14,3": "iPad Pro 11 (第4世代)",
    "iPad14,4": "iPad Pro 11 (第4世代)",
    "iPad14,5": "iPad Pro 12.9 (第6世代)",
    "iPad14,6": "iPad Pro 12.9 (第6世代)",
    "iPad14,8": "iPad Air 11 (M2)",
    "iPad14,9": "iPad Air 11 (M2)",
    "iPad14,10": "iPad Air 13 (M2)",
    "iPad14,11": "iPad Air 13 (M2)",
    "iPad15,3": "iPad Air 11 (M3)",
    "iPad15,4": "iPad Air 11 (M3)",
    "iPad15,5": "iPad Air 13 (M3)",
    "iPad15,6": "iPad Air 13 (M3)",
    "iPad15,7": "iPad (A16)",
    "iPad15,8": "iPad (A16)",
    "iPad16,1": "iPad mini (A17 Pro)",
    "iPad16,2": "iPad mini (A17 Pro)",
    "iPad16,3": "iPad Pro 11 (M4)",
    "iPad16,4": "iPad Pro 11 (M4)",
    "iPad16,5": "iPad Pro 13 (M4)",
    "iPad16,6": "iPad Pro 13 (M4)",
    "iPad16,8": "iPad Air 11 (M4)",
    "iPad16,9": "iPad Air 11 (M4)",
    "iPad16,10": "iPad Air 13 (M4)",
    "iPad16,11": "iPad Air 13 (M4)",
    "iPad17,1": "iPad Pro 11 (M5)",
    "iPad17,2": "iPad Pro 11 (M5)",
    "iPad17,3": "iPad Pro 13 (M5)",
    "iPad17,4": "iPad Pro 13 (M5)",

    // iPod
    "iPod7,1": "iPod touch (第6世代)",
    "iPod9,1": "iPod touch (第7世代)",

    // Apple Watch
    "Watch3,1": "Apple Watch 3 (38mm)",
    "Watch3,2": "Apple Watch 3 (38mm) Cellular",
    "Watch3,3": "Apple Watch 3 (42mm)",
    "Watch3,4": "Apple Watch 3 (42mm) Cellular",
    "Watch4,1": "Apple Watch 4 (40mm)",
    "Watch4,2": "Apple Watch 4 (40mm)",
    "Watch4,3": "Apple Watch 4 (44mm)",
    "Watch4,4": "Apple Watch 4 (44mm)",
    "Watch5,1": "Apple Watch 5 (40mm)",
    "Watch5,2": "Apple Watch 5 (44mm)",
    "Watch5,3": "Apple Watch 5 (40mm)",
    "Watch5,4": "Apple Watch 5 (44mm)",
    "Watch5,9": "Apple Watch SE (第1世代) (40mm)",
    "Watch5,10": "Apple Watch SE (第1世代) (44mm)",
    "Watch5,11": "Apple Watch SE (第1世代) (40mm)",
    "Watch5,12": "Apple Watch SE (第1世代) (44mm)",
    "Watch6,1": "Apple Watch 6 (40mm)",
    "Watch6,2": "Apple Watch 6 (44mm)",
    "Watch6,3": "Apple Watch 6 (40mm)",
    "Watch6,4": "Apple Watch 6 (44mm)",
    "Watch6,6": "Apple Watch 7 (41mm)",
    "Watch6,7": "Apple Watch 7 (45mm)",
    "Watch6,8": "Apple Watch 7 (41mm)",
    "Watch6,9": "Apple Watch 7 (45mm)",
    "Watch6,10": "Apple Watch 8 (41mm)",
    "Watch6,11": "Apple Watch 8 (45mm)",
    "Watch6,12": "Apple Watch 8 (41mm)",
    "Watch6,13": "Apple Watch 8 (45mm)",
    "Watch6,14": "Apple Watch SE (第2世代) (40mm)",
    "Watch6,15": "Apple Watch SE (第2世代) (44mm)",
    "Watch6,16": "Apple Watch SE (第2世代) (40mm)",
    "Watch6,17": "Apple Watch SE (第2世代) (44mm)",
    "Watch6,18": "Apple Watch Ultra (第1世代)",
    "Watch7,1": "Apple Watch 9 (41mm)",
    "Watch7,2": "Apple Watch 9 (45mm)",
    "Watch7,3": "Apple Watch 9 (41mm)",
    "Watch7,4": "Apple Watch 9 (45mm)",
    "Watch7,5": "Apple Watch Ultra (第2世代)",
    "Watch7,8": "Apple Watch 10 (42mm)",
    "Watch7,9": "Apple Watch 10 (46mm)",
    "Watch7,10": "Apple Watch 10 (42mm)",
    "Watch7,11": "Apple Watch 10 (46mm)",
    "Watch7,13": "Apple Watch SE (第3世代) (40mm)",
    "Watch7,14": "Apple Watch SE (第3世代) (44mm)",
    "Watch7,15": "Apple Watch SE (第3世代) (40mm)",
    "Watch7,16": "Apple Watch SE (第3世代) (44mm)",
    "Watch7,17": "Apple Watch 11 (42mm)",
    "Watch7,18": "Apple Watch 11 (46mm)",
    "Watch7,19": "Apple Watch 11 (42mm)",
    "Watch7,20": "Apple Watch 11 (46mm)",
    "Watch7,12": "Apple Watch Ultra (第3世代)",
    "Watch8,1": "Apple Watch Ultra (第4世代)",
    "Watch8,2": "Apple Watch 12 (42mm)",
    "Watch8,3": "Apple Watch 12 (46mm)",
    "Watch8,4": "Apple Watch 12 (42mm) Cellular",
    "Watch8,5": "Apple Watch 12 (46mm) Cellular",

    // Accessories
    "A3385": "iPhone Air MagSafeバッテリー",
  ]

  // MARK: - Board ID から識別子へのマッピング
  static let boardToIdentifier: [String: String] = [
    // iPhone
    "N66AP": "iPhone8,1",
    "N66mAP": "iPhone8,1",
    "N71AP": "iPhone8,2",
    "N71mAP": "iPhone8,2",
    "N69AP": "iPhone8,4",
    "N69uAP": "iPhone8,4",
    "D10AP": "iPhone9,1",
    "D101AP": "iPhone9,3",
    "D111AP": "iPhone9,2",
    "D11AP": "iPhone9,4",
    "D201AP": "iPhone10,4",
    "D20AP": "iPhone10,1",
    "D211AP": "iPhone10,5",
    "D21AP": "iPhone10,2",
    "D221AP": "iPhone10,6",
    "D22AP": "iPhone10,3",
    "D321AP": "iPhone11,2",
    "D331AP": "iPhone11,4",
    "D331pAP": "iPhone11,6",
    "N841AP": "iPhone11,8",
    "N104AP": "iPhone12,1",
    "D421AP": "iPhone12,3",
    "D431AP": "iPhone12,5",
    "D79AP": "iPhone12,8",
    "D52gAP": "iPhone13,1",
    "D53gAP": "iPhone13,2",
    "D53pAP": "iPhone13,3",
    "D54pAP": "iPhone13,4",
    "D16AP": "iPhone14,4",
    "D17AP": "iPhone14,5",
    "D63AP": "iPhone14,2",
    "D64AP": "iPhone14,3",
    "D49AP": "iPhone14,6",
    "D27AP": "iPhone14,7",
    "D28AP": "iPhone14,8",
    "D73AP": "iPhone15,2",
    "D74AP": "iPhone15,3",
    "D37AP": "iPhone15,4",
    "D38AP": "iPhone15,5",
    "D83AP": "iPhone16,1",
    "D84AP": "iPhone16,2",
    "D47AP": "iPhone17,3",
    "D48AP": "iPhone17,4",
    "D93AP": "iPhone17,1",
    "D94AP": "iPhone17,2",
    "V59AP": "iPhone17,5",
    "V57AP": "iPhone18,3",
    "D23AP": "iPhone18,4",
    "V53AP": "iPhone18,1",
    "V54AP": "iPhone18,2",
    "V159AP": "iPhone18,5",
    "V63AP": "iPhone19,2",
    "V64AP": "iPhone19,3",
    "V68AP": "iPhone19,4",
    "V64sAP": "iPhone19,7",

    // iPad
    "J81AP": "iPad5,3",
    "J82AP": "iPad5,4",
    "J96AP": "iPad5,1",
    "J97AP": "iPad5,2",
    "J98aAP": "iPad6,7",
    "J99aAP": "iPad6,8",
    "J127AP": "iPad6,3",
    "J128AP": "iPad6,4",
    "J71sAP": "iPad6,11",
    "J71tAP": "iPad6,11",
    "J72sAP": "iPad6,12",
    "J72tAP": "iPad6,12",
    "J207AP": "iPad7,3",
    "J208AP": "iPad7,4",
    "J120AP": "iPad7,1",
    "J121AP": "iPad7,2",
    "J71bAP": "iPad7,5",
    "J72bAP": "iPad7,6",
    "J317AP": "iPad8,1",
    "J317xAP": "iPad8,2",
    "J318AP": "iPad8,3",
    "J318xAP": "iPad8,4",
    "J320AP": "iPad8,5",
    "J320xAP": "iPad8,6",
    "J321AP": "iPad8,7",
    "J321xAP": "iPad8,8",
    "J210AP": "iPad11,1",
    "J211AP": "iPad11,2",
    "J217AP": "iPad11,3",
    "J218AP": "iPad11,4",
    "J171AP": "iPad7,11",
    "J172AP": "iPad7,12",
    "J417AP": "iPad8,10",
    "J418AP": "iPad8,9",
    "J420AP": "iPad8,11",
    "J421AP": "iPad8,12",
    "J171aAP": "iPad11,6",
    "J172aAP": "iPad11,7",
    "J307AP": "iPad13,1",
    "J308AP": "iPad13,2",
    "J517AP": "iPad13,4",
    "J517xAP": "iPad13,5",
    "J518AP": "iPad13,6",
    "J518xAP": "iPad13,7",
    "J523AP": "iPad13,10",
    "J523xAP": "iPad13,11",
    "J522AP": "iPad13,8",
    "J522xAP": "iPad13,9",
    "J310AP": "iPad14,1",
    "J311AP": "iPad14,2",
    "J181AP": "iPad12,1",
    "J182AP": "iPad12,2",
    "J407AP": "iPad13,16",
    "J408AP": "iPad13,17",
    "J617AP": "iPad14,3",
    "J618AP": "iPad14,4",
    "J620AP": "iPad14,5",
    "J621AP": "iPad14,6",
    "J271AP": "iPad13,18",
    "J272AP": "iPad13,19",
    "J717AP": "iPad16,3",
    "J718AP": "iPad16,4",
    "J720AP": "iPad16,5",
    "J721AP": "iPad16,6",
    "J507AP": "iPad14,8",
    "J508AP": "iPad14,9",
    "J537AP": "iPad14,10",
    "J538AP": "iPad14,11",
    "J410AP": "iPad16,1",
    "J411AP": "iPad16,2",
    "J607AP": "iPad15,3",
    "J608AP": "iPad15,4",
    "J637AP": "iPad15,5",
    "J638AP": "iPad15,6",
    "J481AP": "iPad15,7",
    "J482AP": "iPad15,8",
    "J707AP": "iPad16,8",
    "J708AP": "iPad16,9",
    "J737AP": "iPad16,10",
    "J738AP": "iPad16,11",
    "J817AP": "iPad17,1",
    "J818AP": "iPad17,2",
    "J820AP": "iPad17,3",
    "J821AP": "iPad17,4",

    // iPod
    "N112AP": "iPod9,1",

    // Apple Watch
    "N240AP": "Watch8,1",
    "N237sAP": "Watch8,2",
    "N237bAP": "Watch8,3",
    "N238sAP": "Watch8,4",
    "N238bAP": "Watch8,5",
  ]

  // MARK: - SoC情報（機種名からSoCを取得）
  static let socInfo: [String: String] = [
    // iPhone
    "iPhone Duo": "A20 Pro",
    "iPhone 18 Pro Max": "A20 Pro",
    "iPhone 18 Pro": "A20 Pro",
    "iPhone 17 Pro Max": "A19 Pro",
    "iPhone Air": "A19 Pro",
    "iPhone 17 Pro": "A19 Pro",
    "iPhone 17": "A19",
    "iPhone 17e": "A19",
    "iPhone 16e": "A18",
    "iPhone 16 Pro Max": "A18 Pro",
    "iPhone 16 Plus": "A18",
    "iPhone 16 Pro": "A18 Pro",
    "iPhone 16": "A18",
    "iPhone 15 Pro Max": "A17 Pro",
    "iPhone 15 Plus": "A16 Bionic",
    "iPhone 15 Pro": "A17 Pro",
    "iPhone 15": "A16 Bionic",
    "iPhone 14 Pro Max": "A16 Bionic",
    "iPhone 14 Plus": "A15 Bionic",
    "iPhone 14 Pro": "A16 Bionic",
    "iPhone 14": "A15 Bionic",
    "iPhone 13 Pro Max": "A15 Bionic",
    "iPhone 13 Pro": "A15 Bionic",
    "iPhone 13 mini": "A15 Bionic",
    "iPhone 13": "A15 Bionic",
    "iPhone 12 Pro Max": "A14 Bionic",
    "iPhone 12 Pro": "A14 Bionic",
    "iPhone 12 mini": "A14 Bionic",
    "iPhone 12": "A14 Bionic",
    "iPhone 11 Pro Max": "A13 Bionic",
    "iPhone 11 Pro": "A13 Bionic",
    "iPhone 11": "A13 Bionic",
    "iPhone XS Max": "A12 Bionic",
    "iPhone XS": "A12 Bionic",
    "iPhone XR": "A12 Bionic",
    "iPhone X": "A11 Bionic",
    "iPhone SE (第3世代)": "A15 Bionic",
    "iPhone SE (第2世代)": "A13 Bionic",
    "iPhone SE (第1世代)": "A9",
    "iPhone 8 Plus": "A11 Bionic",
    "iPhone 8": "A11 Bionic",
    "iPhone 7 Plus": "A10 Fusion",
    "iPhone 7": "A10 Fusion",
    "iPhone 6s Plus": "A9",
    "iPhone 6s": "A9",

    // iPad
    "iPad Pro 13 (M5)": "M5",
    "iPad Pro 13 (M4)": "M4",
    "iPad Pro 12.9 (第6世代)": "M2",
    "iPad Pro 12.9 (第5世代)": "M1",
    "iPad Pro 12.9 (第4世代)": "A12Z Bionic",
    "iPad Pro 12.9 (第3世代)": "A12X Bionic",
    "iPad Pro 12.9 (第2世代)": "A10X Fusion",
    "iPad Pro 12.9 (第1世代)": "A9X",
    "iPad Pro 11 (M5)": "M5",
    "iPad Pro 11 (M4)": "M4",
    "iPad Pro 11 (第4世代)": "M2",
    "iPad Pro 11 (第3世代)": "M1",
    "iPad Pro 11 (第2世代)": "A12Z Bionic",
    "iPad Pro 11 (第1世代)": "A12X Bionic",
    "iPad Pro 10.5": "A10X Fusion",
    "iPad Pro 9.7": "A9X",
    "iPad mini (A17 Pro)": "A17 Pro",
    "iPad mini (第6世代)": "A15 Bionic",
    "iPad mini (第5世代)": "A12 Bionic",
    "iPad mini (第4世代)": "A8",
    "iPad (A16)": "A16 Bionic",
    "iPad (第10世代)": "A14 Bionic",
    "iPad (第9世代)": "A13 Bionic",
    "iPad (第8世代)": "A12 Bionic",
    "iPad (第7世代)": "A10 Fusion",
    "iPad (第6世代)": "A10 Fusion",
    "iPad (第5世代)": "A9",
    "iPad Air 13 (M4)": "M4",
    "iPad Air 11 (M4)": "M4",
    "iPad Air 13 (M3)": "M3",
    "iPad Air 11 (M3)": "M3",
    "iPad Air 13 (M2)": "M2",
    "iPad Air 11 (M2)": "M2",
    "iPad Air (第5世代)": "M1",
    "iPad Air (第4世代)": "A14 Bionic",
    "iPad Air (第3世代)": "A12 Bionic",
    "iPad Air (第2世代)": "A8X",
    "iPad Air (第1世代)": "A7",

    // iPod
    "iPod touch (第7世代)": "A10 Fusion",
    "iPod touch (第6世代)": "A8",

    // Apple Watch
    "Apple Watch Ultra (第4世代)": "S11",
    "Apple Watch 12 (46mm)": "S11",
    "Apple Watch 12 (42mm)": "S11",
    "Apple Watch 12 (46mm) Cellular": "S10",
    "Apple Watch 12 (42mm) Cellular": "S10",
    "Apple Watch Ultra (第3世代)": "S10",
    "Apple Watch Ultra (第2世代)": "S9",
    "Apple Watch Ultra (第1世代)": "S8",
    "Apple Watch SE (第3世代) (44mm)": "S10",
    "Apple Watch SE (第3世代) (40mm)": "S10",
    "Apple Watch SE (第2世代) (44mm)": "S8",
    "Apple Watch SE (第2世代) (40mm)": "S8",
    "Apple Watch SE (第1世代) (44mm)": "S5",
    "Apple Watch SE (第1世代) (40mm)": "S5",
    "Apple Watch 11 (46mm)": "S10",
    "Apple Watch 11 (42mm)": "S10",
    "Apple Watch 10 (46mm)": "S10",
    "Apple Watch 10 (42mm)": "S10",
    "Apple Watch 9 (45mm)": "S9",
    "Apple Watch 9 (41mm)": "S9",
    "Apple Watch 8 (45mm)": "S8",
    "Apple Watch 8 (41mm)": "S8",
    "Apple Watch 7 (45mm)": "S7",
    "Apple Watch 7 (41mm)": "S7",
    "Apple Watch 6 (44mm)": "S6",
    "Apple Watch 6 (40mm)": "S6",
    "Apple Watch 5 (44mm)": "S5",
    "Apple Watch 5 (40mm)": "S5",
    "Apple Watch 4 (44mm)": "S4",
    "Apple Watch 4 (40mm)": "S4",
    "Apple Watch 3 (42mm) Cellular": "S3",
    "Apple Watch 3 (42mm)": "S3",
    "Apple Watch 3 (38mm) Cellular": "S3",
    "Apple Watch 3 (38mm)": "S3",
  ]

  // MARK: - 設計容量（機種名からmAhを取得）
  static let designCapacities: [String: Int] = [
    // iPhone
    "iPhone Duo": 4700,
    "iPhone 18 Pro Max": 5567,
    "iPhone 18 Pro": 4288,
    "iPhone 17 Pro Max": 5088,
    "iPhone Air": 3149,
    "iPhone 17 Pro": 4252,
    "iPhone 17": 3692,
    "iPhone 17e": 4005,
    "iPhone 16e": 4005,
    "iPhone 16 Pro Max": 4685,
    "iPhone 16 Plus": 4674,
    "iPhone 16 Pro": 3582,
    "iPhone 16": 3561,
    "iPhone 15 Pro Max": 4422,
    "iPhone 15 Plus": 4383,
    "iPhone 15 Pro": 3274,
    "iPhone 15": 3349,
    "iPhone 14 Pro Max": 4323,
    "iPhone 14 Plus": 4325,
    "iPhone 14 Pro": 3200,
    "iPhone 14": 3279,
    "iPhone 13 Pro Max": 4352,
    "iPhone 13 Pro": 3095,
    "iPhone 13 mini": 2406,
    "iPhone 13": 3227,
    "iPhone 12 Pro Max": 3687,
    "iPhone 12 Pro": 2815,
    "iPhone 12 mini": 2227,
    "iPhone 12": 2815,
    "iPhone 11 Pro Max": 3969,
    "iPhone 11 Pro": 3046,
    "iPhone 11": 3110,
    "iPhone XS Max": 3174,
    "iPhone XS": 2658,
    "iPhone XR": 2942,
    "iPhone X": 2700,
    "iPhone SE (第3世代)": 2018,
    "iPhone SE (第2世代)": 1821,
    "iPhone SE (第1世代)": 1624,
    "iPhone 8 Plus": 2675,
    "iPhone 8": 1821,
    "iPhone 7 Plus": 2906,
    "iPhone 7": 1960,
    "iPhone 6s Plus": 2705,
    "iPhone 6s": 1715,

    // iPad
    "iPad Pro 13 (M5)": 10340,
    "iPad Pro 13 (M4)": 10340,
    "iPad Pro 12.9 (第6世代)": 10758,
    "iPad Pro 12.9 (第5世代)": 10533,
    "iPad Pro 12.9 (第4世代)": 9720,
    "iPad Pro 12.9 (第3世代)": 9720,
    "iPad Pro 12.9 (第2世代)": 10850,
    "iPad Pro 12.9 (第1世代)": 10307,
    "iPad Pro 11 (M5)": 8340,
    "iPad Pro 11 (M4)": 8340,
    "iPad Pro 11 (第4世代)": 7538,
    "iPad Pro 11 (第3世代)": 7538,
    "iPad Pro 11 (第2世代)": 7600,
    "iPad Pro 11 (第1世代)": 7812,
    "iPad Pro 10.5": 8134,
    "iPad Pro 9.7": 7306,
    "iPad mini (A17 Pro)": 5124,
    "iPad mini (第6世代)": 5124,
    "iPad mini (第5世代)": 5124,
    "iPad mini (第4世代)": 5124,
    "iPad (A16)": 7698,
    "iPad (第10世代)": 7606,
    "iPad (第9世代)": 8686,
    "iPad (第8世代)": 8686,
    "iPad (第7世代)": 8827,
    "iPad (第6世代)": 8827,
    "iPad (第5世代)": 8827,
    "iPad Air 13 (M4)": 9705,
    "iPad Air 11 (M4)": 7606,
    "iPad Air 13 (M3)": 9705,
    "iPad Air 11 (M3)": 7606,
    "iPad Air 13 (M2)": 9705,
    "iPad Air 11 (M2)": 7606,
    "iPad Air (第5世代)": 7526,
    "iPad Air (第4世代)": 7606,
    "iPad Air (第3世代)": 8134,
    "iPad Air (第2世代)": 7340,
    "iPad Air (第1世代)": 7340,

    // iPod
    "iPod touch (第7世代)": 1043,
    "iPod touch (第6世代)": 1043,

    // Apple Watch
    // Provisional: reuse Series 11 / Ultra 3 capacities until confirmed.
    "Apple Watch Ultra (第4世代)": 599,
    "Apple Watch 12 (46mm)": 363,
    "Apple Watch 12 (42mm)": 322,
    "Apple Watch Ultra (第3世代)": 599,
    "Apple Watch Ultra (第2世代)": 564,
    "Apple Watch Ultra (第1世代)": 542,
    "Apple Watch SE (第3世代) (44mm)": 330,
    "Apple Watch SE (第3世代) (40mm)": 263,
    "Apple Watch SE (第2世代) (44mm)": 296,
    "Apple Watch SE (第2世代) (40mm)": 245,
    "Apple Watch SE (第1世代) (44mm)": 296,
    "Apple Watch SE (第1世代) (40mm)": 245,
    "Apple Watch 11 (46mm)": 363,
    "Apple Watch 11 (42mm)": 322,
    "Apple Watch 10 (46mm)": 327,
    "Apple Watch 10 (42mm)": 308,
    "Apple Watch 9 (45mm)": 308,
    "Apple Watch 9 (41mm)": 282,
    "Apple Watch 8 (45mm)": 308,
    "Apple Watch 8 (41mm)": 282,
    "Apple Watch 7 (45mm)": 308,
    "Apple Watch 7 (41mm)": 284,
    "Apple Watch 6 (44mm)": 303,
    "Apple Watch 6 (40mm)": 265,
    "Apple Watch 5 (44mm)": 296,
    "Apple Watch 5 (40mm)": 245,
    "Apple Watch 4 (44mm)": 291,
    "Apple Watch 4 (40mm)": 224,
    "Apple Watch 3 (42mm) Cellular": 279,
    "Apple Watch 3 (42mm)": 342,
    "Apple Watch 3 (38mm) Cellular": 262,
    "Apple Watch 3 (38mm)": 262,

    // Accessories
    "iPhone Air MagSafeバッテリー": 3149,
  ]

  static let modelNumbers: [String: [String]] = [
    "iPhone Duo": ["A3447", "A3719", "A3720", "A3721"],
    "iPhone 18 Pro": ["A3472", "A3713", "A3714", "A3715"],
    "iPhone 18 Pro Max": ["A3473", "A3716", "A3717", "A3718"],
  ]

  /// GPS/Cellularでバッテリー容量を共通扱いする機種。
  static let capacityReferenceNames: [String: String] = [
    "Apple Watch 12 (42mm) Cellular": "Apple Watch 12 (42mm)",
    "Apple Watch 12 (46mm) Cellular": "Apple Watch 12 (46mm)",
  ]

  static let modelNumbersByIdentifier: [String: [String]] = [
    "iPhone19,2": ["A3472", "A3713", "A3714", "A3715"],
    "iPhone19,3": ["A3473"],
    "iPhone19,4": ["A3447", "A3719", "A3720", "A3721"],
    "iPhone19,7": ["A3716", "A3717", "A3718"],
    "Watch8,1": ["A3579", "A3580"],
    "Watch8,2": ["A3581", "A3583"],
    "Watch8,3": ["A3584", "A3585"],
    "Watch8,4": ["A3582", "A3586"],
    "Watch8,5": ["A3587", "A3588"],
  ]

  static let capacityVariants: [String: [DeviceCapacityVariant]] = [
    "iPhone 17": simVariants(esim: 3692, physicalSIM: 3692),
    "iPhone 17e": simVariants(esim: 4005, physicalSIM: 4005),
    "iPhone 17 Pro": simVariants(esim: 4252, physicalSIM: 3988),
    "iPhone 17 Pro Max": simVariants(esim: 5088, physicalSIM: 4823),
    "iPhone 18 Pro": simVariants(esim: 4288, physicalSIM: 4056),
    "iPhone 18 Pro Max": simVariants(esim: 5567, physicalSIM: 5391),
  ]

  private static func simVariants(esim: Int, physicalSIM: Int?) -> [DeviceCapacityVariant] {
    [
      DeviceCapacityVariant(configuration: .esim, capacity: esim, region: nil),
      DeviceCapacityVariant(configuration: .physicalSIM, capacity: physicalSIM, region: "HK/CN"),
    ]
  }

  // MARK: - 旧API互換用
  /// Standard definitions plus locally saved device profiles.
  static var deviceNames: [String: String] {
    return DeviceProfileStore.shared.names
  }

  // MARK: - ヘルパーメソッド

  /// 識別子（例: iPhone16,1）から機種名を取得
  static func getDeviceName(for identifier: String) -> String? {
    return deviceNames[identifier]
  }

  /// 保存・集計に使う機種名は変えず、画面表示時だけ世代表記を選択言語へ変換する。
  static func localizedName(for canonicalName: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "第([0-9]+)世代"),
      let match = regex.firstMatch(in: canonicalName, range: NSRange(canonicalName.startIndex..., in: canonicalName)),
      let numberRange = Range(match.range(at: 1), in: canonicalName),
      let wholeRange = Range(match.range(at: 0), in: canonicalName)
    else {
      if canonicalName == "iPhone Air MagSafeバッテリー" {
        return L10n.language == "ja" ? canonicalName : "iPhone Air MagSafe Battery"
      }
      return canonicalName
    }
    let number = String(canonicalName[numberRange])
    let replacement: String
    switch L10n.language {
    case "ja": replacement = "第\(number)世代"
    case "de": replacement = "\(number). Generation"
    case "es": replacement = "\(number).ª generación"
    case "fr": replacement = "\(number)e génération"
    case "ko": replacement = "\(number)세대"
    case "zh-Hans", "zh-Hant": replacement = "第\(number)代"
    default: replacement = "\(englishOrdinal(number)) generation"
    }
    return canonicalName.replacingCharacters(in: wholeRange, with: replacement)
  }

  private static func englishOrdinal(_ value: String) -> String {
    guard let number = Int(value) else { return value }
    let lastTwo = number % 100
    let suffix: String
    if 11...13 ~= lastTwo { suffix = "th" }
    else {
      switch number % 10 {
      case 1: suffix = "st"
      case 2: suffix = "nd"
      case 3: suffix = "rd"
      default: suffix = "th"
      }
    }
    return "\(number)\(suffix)"
  }

  /// 機種名から識別子を取得（例: "Apple Watch 9 (45mm)" -> "Watch7,2"）
  static func getIdentifierForDeviceName(_ deviceName: String) -> String? {
    return DeviceProfileStore.shared.modelIdentifier(for: deviceName)
  }

  /// 実行中デバイスのモデル識別子を取得（hw.machine を利用）
  /// iOS/macOS 上で動作している場合に自端末の識別子（例: "iPhone13,2"）を返す
  static func localModelIdentifier() -> String? {
    let overrideId = AppSettings.shared.overrideLocalModelIdentifier
    if !overrideId.isEmpty {
      return overrideId
    }

    var size: Int = 0
    // 取得サイズをまず問い合わせ
    if sysctlbyname("hw.machine", nil, &size, nil, 0) != 0 {
      return nil
    }
    var machine = [CChar](repeating: 0, count: Int(size))
    if sysctlbyname("hw.machine", &machine, &size, nil, 0) != 0 {
      return nil
    }
    return String(cString: machine)
  }

  /// Board ID（例: D83AP）から識別子を取得
  static func getIdentifier(for boardId: String) -> String? {
    return DeviceProfileStore.shared.identifier(for: boardId)
  }

  /// Board ID から機種名を取得
  static func getDeviceNameFromBoard(_ boardId: String) -> String? {
    guard let identifier = getIdentifier(for: boardId) else { return nil }
    return getDeviceName(for: identifier)
  }

  /// 機種名からSoCを取得
  static func getSoC(for deviceName: String) -> String? {
    return DeviceProfileStore.shared.soc(deviceName)
  }

  /// 識別子からSoCを取得
  static func getSoCFromIdentifier(_ identifier: String) -> String? {
    guard let deviceName = getDeviceName(for: identifier) else { return nil }
    return getSoC(for: deviceName)
  }

  /// 機種名から設計容量を取得
  static func getCapacity(for deviceName: String) -> Int? {
    return DeviceProfileStore.shared.capacity(deviceName)
  }

  /// 識別子から設計容量を取得
  static func getCapacityFromIdentifier(_ identifier: String) -> Int? {
    guard let deviceName = getDeviceName(for: identifier) else { return nil }
    return getCapacity(for: deviceName)
  }

  // MARK: - 階層的データ取得

  enum Category: String, CaseIterable, Identifiable {
    case iphone = "iPhone"
    case ipad = "iPad"
    case watch = "Apple Watch"
    case ipod = "iPod"

    var id: String { self.rawValue }
    var localizedName: String {
      switch self {
      case .iphone: return L10n.string("category_iphone", table: "Common")
      case .ipad: return L10n.string("category_ipad", table: "Common")
      case .watch: return L10n.string("category_watch", table: "Common")
      case .ipod: return "iPod"
      }
    }
  }

  /// カテゴリに属するシリーズ一覧を取得
  static func getSeries(for category: Category) -> [String] {
    let keywords = ["Pro", "Air", "mini", "SE", "Ultra", "Plus"]
    var seriesToMaxIdentifier: [String: String] = [:]

    for (identifier, name) in deviceNames {
      guard identifier.hasPrefix(category == .watch ? "Watch" : category.rawValue) else { continue }

      let components = name.components(separatedBy: " ")
      var foundKeyword = false
      for keyword in keywords {
        if components.contains(keyword) {
          if let currentMax = seriesToMaxIdentifier[keyword] {
            if identifier.compare(currentMax, options: .numeric) == .orderedDescending {
              seriesToMaxIdentifier[keyword] = identifier
            }
          } else {
            seriesToMaxIdentifier[keyword] = identifier
          }
          foundKeyword = true
        }
      }

      if !foundKeyword {
        if let currentMax = seriesToMaxIdentifier["Standard"] {
          if identifier.compare(currentMax, options: .numeric) == .orderedDescending {
            seriesToMaxIdentifier["Standard"] = identifier
          }
        } else {
          seriesToMaxIdentifier["Standard"] = identifier
        }
      }
    }

    // シリーズを最新モデルの識別子順にソート
    return seriesToMaxIdentifier.keys.sorted { s1, s2 in
      let id1 = seriesToMaxIdentifier[s1]!
      let id2 = seriesToMaxIdentifier[s2]!
      return id1.compare(id2, options: .numeric) == .orderedDescending
    }
  }

  /// カテゴリとシリーズに属するモデル一覧を取得
  static func getModels(for category: Category, series: String) -> [String] {
    let keywords = ["Pro", "Air", "mini", "SE", "Ultra", "Plus"]

    // モデル名ごとに、そのモデルに属する最大の識別子を紐付ける
    var modelToMaxIdentifier: [String: String] = [:]
    for (identifier, name) in deviceNames {
      guard identifier.hasPrefix(category == .watch ? "Watch" : category.rawValue) else { continue }

      let components = name.components(separatedBy: " ")
      let isStandard = !components.contains(where: { keywords.contains($0) })

      if (series == "Standard" && isStandard)
        || (series != "Standard" && components.contains(series))
      {
        if let currentMax = modelToMaxIdentifier[name] {
          if identifier.compare(currentMax, options: .numeric) == .orderedDescending {
            modelToMaxIdentifier[name] = identifier
          }
        } else {
          modelToMaxIdentifier[name] = identifier
        }
      }
    }

    // 識別子の降順（新しい順）でソートしてモデル名を返す
    return modelToMaxIdentifier.keys.sorted { name1, name2 in
      let id1 = modelToMaxIdentifier[name1]!
      let id2 = modelToMaxIdentifier[name2]!
      return id1.compare(id2, options: .numeric) == .orderedDescending
    }
  }

  /// 機種名から最初の識別子を取得
  static func getFirstIdentifier(for deviceName: String) -> String? {
    return DeviceProfileStore.shared.modelIdentifier(for: deviceName)
  }
}
