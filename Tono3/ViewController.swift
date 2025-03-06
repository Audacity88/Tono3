//
//  ViewController.swift
//  CoreML in ARKit
//
//  Created by Hanley Weng on 14/7/17.
//  Copyright © 2017 CompanyName. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AVFoundation
import Speech
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    // SCENE
    @IBOutlet var sceneView: ARSCNView!
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    var latestPrediction : String = "…" // a variable containing the latest CoreML prediction
    var latestChineseTranslation: String = "..." // Chinese translation of the latest prediction
    var latestPinyin: String = "..." // Pinyin for the latest Chinese translation
    
    // Store placed nodes to prevent duplicates
    var placedNodes: [SCNNode] = []
    
    // Audio Player for pronunciation
    var audioPlayer: AVAudioPlayer?
    
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    @IBOutlet weak var debugTextView: UITextView!
    
    // Dictionary for English to Chinese translations
    // This is a simple dictionary for demonstration purposes
    // In a real app, this would be loaded from a database or API
    let translationDictionary: [String: (chinese: String, pinyin: String)] = [
        "cup": (chinese: "杯子", pinyin: "bēizi"),
        "bottle": (chinese: "瓶子", pinyin: "píngzi"),
        "chair": (chinese: "椅子", pinyin: "yǐzi"),
        "table": (chinese: "桌子", pinyin: "zhuōzi"),
        "book": (chinese: "书", pinyin: "shū"),
        "pen": (chinese: "笔", pinyin: "bǐ"),
        "phone": (chinese: "手机", pinyin: "shǒujī"),
        "computer": (chinese: "电脑", pinyin: "diànnǎo"),
        "keyboard": (chinese: "键盘", pinyin: "jiànpán"),
        "mouse": (chinese: "鼠标", pinyin: "shǔbiāo"),
        "monitor": (chinese: "显示器", pinyin: "xiǎnshìqì"),
        "desk": (chinese: "桌子", pinyin: "zhuōzi"),
        "lamp": (chinese: "灯", pinyin: "dēng"),
        "window": (chinese: "窗户", pinyin: "chuānghu"),
        "door": (chinese: "门", pinyin: "mén"),
        "wall": (chinese: "墙", pinyin: "qiáng"),
        "floor": (chinese: "地板", pinyin: "dìbǎn"),
        "ceiling": (chinese: "天花板", pinyin: "tiānhuābǎn"),
        "sofa": (chinese: "沙发", pinyin: "shāfā"),
        "television": (chinese: "电视", pinyin: "diànshì"),
        "remote": (chinese: "遥控器", pinyin: "yáokòngqì"),
        "clock": (chinese: "钟", pinyin: "zhōng"),
        "watch": (chinese: "手表", pinyin: "shǒubiǎo"),
        "glasses": (chinese: "眼镜", pinyin: "yǎnjìng"),
        "shoe": (chinese: "鞋", pinyin: "xié"),
        "hat": (chinese: "帽子", pinyin: "màozi"),
        "shirt": (chinese: "衬衫", pinyin: "chènshān"),
        "pants": (chinese: "裤子", pinyin: "kùzi"),
        "jacket": (chinese: "夹克", pinyin: "jiákè"),
        "coat": (chinese: "外套", pinyin: "wàitào")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        //////////////////////////////////////////////////
        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        //////////////////////////////////////////////////
        
        // Set up Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else { // (Optional) This can be replaced with other models on https://developer.apple.com/machine-learning/
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
        }
        
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
        
        // Set up audio session for playback
        setupAudioSession()
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory("AVAudioSessionCategoryPlayback")
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Interaction
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Get tap location in the AR scene view
        let location = gestureRecognize.location(in: sceneView)
        
        // Perform hit test against existing nodes
        let hitTestResults = sceneView.hitTest(location, options: [:])
        
        // Check if we hit an existing node
        if let hitNode = hitTestResults.first?.node, isNodeInPlacedNodes(hitNode) {
            // We tapped on an existing node, play pronunciation
            playPronunciation()
            
            // Highlight the node briefly to provide visual feedback
            highlightNode(hitNode)
            
            return
        }
        
        // If we didn't hit an existing node, perform a hit test against AR features
        let arHitTestResults = sceneView.hitTest(location, types: [.featurePoint])
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform = closestResult.worldTransform
            let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Check if there's already a node close to this position
            if isPositionNearExistingNode(worldCoord) {
                // If there's a node nearby, don't create a new one
                // Find the closest node and play its pronunciation
                if let closestNode = findClosestNode(to: worldCoord) {
                    playPronunciation()
                    highlightNode(closestNode)
                }
                return
            }
            
            // Create 3D Text with Chinese translation and pinyin
            let node = createNewBubbleParentNode()
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
            
            // Store the node to prevent duplicates
            placedNodes.append(node)
            
            // Play pronunciation audio
            playPronunciation()
            
            // Store object data (would be saved to Core Data in a full implementation)
            storeObjectData()
        }
    }
    
    // Check if a node is in our placed nodes array
    func isNodeInPlacedNodes(_ node: SCNNode) -> Bool {
        // Check if the node or any of its parents are in our placed nodes array
        var currentNode: SCNNode? = node
        while currentNode != nil {
            if placedNodes.contains(currentNode!) {
                return true
            }
            currentNode = currentNode?.parent
        }
        return false
    }
    
    // Check if a position is near an existing node
    func isPositionNearExistingNode(_ position: SCNVector3) -> Bool {
        let threshold: Float = 0.2 // 20cm threshold
        
        for node in placedNodes {
            let distance = distance(position, node.position)
            if distance < threshold {
                return true
            }
        }
        
        return false
    }
    
    // Find the closest node to a position
    func findClosestNode(to position: SCNVector3) -> SCNNode? {
        var closestNode: SCNNode? = nil
        var closestDistance: Float = Float.greatestFiniteMagnitude
        
        for node in placedNodes {
            let dist = distance(position, node.position)
            if dist < closestDistance {
                closestDistance = dist
                closestNode = node
            }
        }
        
        return closestNode
    }
    
    // Calculate distance between two 3D points
    func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    // Highlight a node briefly to provide visual feedback
    func highlightNode(_ node: SCNNode) {
        // Save original scale
        let originalScale = node.scale
        
        // Scale up
        node.scale = SCNVector3(
            originalScale.x * 1.2,
            originalScale.y * 1.2,
            originalScale.z * 1.2
        )
        
        // Scale back down after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            node.scale = originalScale
        }
    }
    
    // Store object data (placeholder for Core Data implementation)
    func storeObjectData() {
        // In a full implementation, this would save the object to Core Data
        print("Storing object: \(latestPrediction) - \(latestChineseTranslation) (\(latestPinyin))")
    }
    
    func createNewBubbleParentNode() -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // Create a parent node for all text elements
        let bubbleNodeParent = SCNNode()
        
        // CHINESE TEXT
        let chineseText = SCNText(string: latestChineseTranslation, extrusionDepth: CGFloat(bubbleDepth))
        var chineseFont = UIFont(name: "PingFangSC-Semibold", size: 0.15)
        chineseFont = chineseFont?.withTraits(traits: .traitBold)
        chineseText.font = chineseFont
        chineseText.alignmentMode = kCAAlignmentCenter
        chineseText.firstMaterial?.diffuse.contents = UIColor.red
        chineseText.firstMaterial?.specular.contents = UIColor.white
        chineseText.firstMaterial?.isDoubleSided = true
        chineseText.chamferRadius = CGFloat(bubbleDepth)
        
        // CHINESE NODE
        let (minBoundChinese, maxBoundChinese) = chineseText.boundingBox
        let chineseNode = SCNNode(geometry: chineseText)
        chineseNode.pivot = SCNMatrix4MakeTranslation((maxBoundChinese.x - minBoundChinese.x)/2, minBoundChinese.y, bubbleDepth/2)
        chineseNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // PINYIN TEXT
        let pinyinText = SCNText(string: latestPinyin, extrusionDepth: CGFloat(bubbleDepth))
        var pinyinFont = UIFont(name: "Avenir-Medium", size: 0.12)
        pinyinText.font = pinyinFont
        pinyinText.alignmentMode = kCAAlignmentCenter
        pinyinText.firstMaterial?.diffuse.contents = UIColor.orange
        pinyinText.firstMaterial?.specular.contents = UIColor.white
        pinyinText.firstMaterial?.isDoubleSided = true
        pinyinText.chamferRadius = CGFloat(bubbleDepth)
        
        // PINYIN NODE
        let (minBoundPinyin, maxBoundPinyin) = pinyinText.boundingBox
        let pinyinNode = SCNNode(geometry: pinyinText)
        pinyinNode.pivot = SCNMatrix4MakeTranslation((maxBoundPinyin.x - minBoundPinyin.x)/2, minBoundPinyin.y, bubbleDepth/2)
        pinyinNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        pinyinNode.position = SCNVector3(0, -0.05, 0)
        
        // ENGLISH TEXT
        let englishText = SCNText(string: latestPrediction, extrusionDepth: CGFloat(bubbleDepth))
        var englishFont = UIFont(name: "Avenir-Light", size: 0.1)
        englishText.font = englishFont
        englishText.alignmentMode = kCAAlignmentCenter
        englishText.firstMaterial?.diffuse.contents = UIColor.white
        englishText.firstMaterial?.specular.contents = UIColor.white
        englishText.firstMaterial?.isDoubleSided = true
        englishText.chamferRadius = CGFloat(bubbleDepth)
        
        // ENGLISH NODE
        let (minBoundEnglish, maxBoundEnglish) = englishText.boundingBox
        let englishNode = SCNNode(geometry: englishText)
        englishNode.pivot = SCNMatrix4MakeTranslation((maxBoundEnglish.x - minBoundEnglish.x)/2, minBoundEnglish.y, bubbleDepth/2)
        englishNode.scale = SCNVector3Make(0.15, 0.15, 0.15)
        englishNode.position = SCNVector3(0, -0.1, 0)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // Add all nodes to parent
        bubbleNodeParent.addChildNode(chineseNode)
        bubbleNodeParent.addChildNode(pinyinNode)
        bubbleNodeParent.addChildNode(englishNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        // Store the current word data with the node
        bubbleNodeParent.name = "\(latestPrediction)|\(latestChineseTranslation)|\(latestPinyin)"
        
        return bubbleNodeParent
    }
    
    // Function to play pronunciation audio
    func playPronunciation() {
        // In a real app, you would load audio files for each word
        // For now, we'll just print a message
        print("Playing pronunciation for: \(latestChineseTranslation) (\(latestPinyin))")
        
        // Example of how to play audio (would need actual audio files)
        /*
        guard let url = Bundle.main.url(forResource: latestPrediction, withExtension: "mp3") else {
            print("Audio file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Could not play audio: \(error)")
        }
        */
    }
    
    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
        
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        
        DispatchQueue.main.async {
            // Print Classifications
            print(classifications)
            print("--")
            
            // Display Debug Text on screen
            var debugText:String = ""
            debugText += classifications
            self.debugTextView.text = debugText
            
            // Store the latest prediction
            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look up Chinese translation and pinyin
            self.translateToChinese(self.latestPrediction)
        }
    }
    
    func translateToChinese(_ englishWord: String) {
        // Extract the main word (remove any descriptors)
        let mainWord = englishWord.components(separatedBy: " ")[0].lowercased()
        
        // Look up in dictionary
        if let translation = translationDictionary[mainWord] {
            latestChineseTranslation = translation.chinese
            latestPinyin = translation.pinyin
        } else {
            // If not found, use a default message
            latestChineseTranslation = "未知"
            latestPinyin = "wèizhī"
        }
        
        // Update debug text
        DispatchQueue.main.async {
            self.debugTextView.text += "\n\nChinese: \(self.latestChineseTranslation)\nPinyin: \(self.latestPinyin)"
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        // let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage!, orientation: myOrientation, options: [:]) // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
        
        ///////////////////////////
        // Run Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
        
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
