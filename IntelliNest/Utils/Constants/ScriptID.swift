//
//  ScriptID.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-11.
//

import Foundation

enum ScriptID: String, Decodable, CaseIterable {
    case roborockDock = "script.docka_bob"
    case roborockSendToBin = "script.bob_send_to_bin"
    case roborockManualEmpty = "script.roborock_manual_empty"
    case roborockKitchen = "script.dammsug_koket"
    case roborockLaundry = "script.dammsug_tvattstugan"
    case roborockCorridor = "script.dammsug_korridoren"
    case roborockHallway = "script.dammsug_hallen"
    case roborockBedroom = "script.dammsug_sovrummet"
    case roborockGym = "script.dammsug_gymmet"
    case roborockLivingroom = "script.dammsug_vardagsrummet"
    case roborockVinceRoom = "script.dammsug_vince_rum"
    case roborockKitchenTable = "script.dammsug_matbord"
    case roborockKitchenStove = "script.dammsug_matlagning"
}
