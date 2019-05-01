//
//  Controller.swift
//  ISLTranslator
//
//  Created by Michael Slattery on 08/04/2019.
//  Copyright © 2019 Michael Slattery. All rights reserved.
//

import Foundation

class Controller {

    var model = ISLModel()
    var graphModel = retrained_graph()
    
    func userIsRecording() -> Bool {
        
        model.isRecording = !model.isRecording
        
        return model.isRecording
    }
    
    func incrementIsCorrect() {
        
        model.isCorrect += 1
    }
    
    func resetIsCorrect(_ percentage: Double, _ label: String) {
        
        model.isCorrect = 0
        model.previousLabel = percentage > 0.7 ? label : ""
    }
    
    func getTopThree(_ output: [String: Double]) -> [[String: Double]] {
        
        var topLabelString = ""
        var midLabelString = ""
        var lowLabelString = ""
        
        var topPercentage: Double = 0
        var midPercentage: Double = 0
        var lowPercentage: Double = 0
        
        var topThreeLabels: [[String: Double]] = []
        
        for dictionary in output {
            
            if dictionary.value > topPercentage {
                
                topLabelString = dictionary.key
                topPercentage = (dictionary.value).truncate(places: 2)
            } else if dictionary.value < topPercentage && dictionary.value > midPercentage {
                
                midLabelString = dictionary.key
                midPercentage = (dictionary.value).truncate(places: 2)
            } else if dictionary.value < midPercentage && dictionary.value > lowPercentage {
                
                lowLabelString = dictionary.key
                lowPercentage = (dictionary.value).truncate(places: 2)
            }
        }
        
        topThreeLabels.append([topLabelString: topPercentage])
        topThreeLabels.append([midLabelString: midPercentage])
        topThreeLabels.append([lowLabelString: lowPercentage])
        
        return topThreeLabels
    }
    
    func clean(_ topThree: [[String: Double]], position: Int) -> String {
        
        return Array(topThree[position].keys)[0] + " " + String(Array(topThree[position].values)[0])
    }
    
    func calculate(output: retrained_graphOutput?, completion: (Bool, [String : Double], Double, String)->()) {
        
        if model.isRecording {
            
            guard let classLabel = output?.classLabel, let percentage = output?.final_result__0[classLabel],
                let final_result = output?.final_result__0 else { return }
            
            if self.model.isCorrect == 5 {
                
                self.incrementIsCorrect()
                completion(true, final_result, percentage, classLabel)
            } else if classLabel == self.model.previousLabel{
                
                self.incrementIsCorrect()
            } else {
                
                self.resetIsCorrect(percentage, classLabel)
            }
            
            completion(true, final_result, 0.0, classLabel)
        }
        
        completion(false, [:], 0.0, "")
    }
}

extension Double {
    
    func truncate(places : Int)-> Double {
        
        return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
    }
}
