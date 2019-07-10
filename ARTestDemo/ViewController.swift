import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    //    拿到模型
    var resentModel = Resnet50()
    //    点击之後的結果
    var hitTestResult: ARHitTestResult!
    //    分析的結果
    var visionRequests = [VNRequest]()
    
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
        
        regiterGestureRecognizers()
    }
    
    // 创建点击手势
    func regiterGestureRecognizers(){
        
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(tapped))
        
        self.sceneView.addGestureRecognizer(tapGes)
    }
    
    @objc func tapped(recognizer: UIGestureRecognizer){
        
        let sceneView = recognizer.view as! ARSCNView //当前画面的 sceneView  = 截圖
        let touchLoaction = self.sceneView.center
        
        guard let currentFrame = sceneView.session.currentFrame else { return } //判別當前是否有像素
        let hitTestResults = sceneView.hitTest(touchLoaction, types: .featurePoint) //识别物件的特征点
        
        if hitTestResults.isEmpty { return }  //如果没有特征点就返回。比如说大晚上黑漆漆一片...
        
        guard let hitTestResult = hitTestResults.first else { return } // 是否為第一個物件.防止多次点击，不知道识别哪个了
        
        self.hitTestResult = hitTestResult //拿到点击的結果
        
        let pixelBuffer = currentFrame.capturedImage // 拿到的圖片转成像素
        
        perfomVisionRequest(pixelBuffer: pixelBuffer)
    }
    
    //    圖片分解成像素 => coreML => ＧＰＵ
    
    func perfomVisionRequest(pixelBuffer: CVPixelBuffer){
        
        let visionModel = try! VNCoreMLModel(for: self.resentModel.model) //  mlmodel干活了
        
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            
            if error != nil { return }
            
            guard let observations = request.results else { return } // 把結果拿出來
            
            let observation = observations.first as! VNClassificationObservation //把結果中的第一位拿出來進行分析
            
            print("Name \(observation.identifier) and confidence is \(observation.confidence)")
            
            DispatchQueue.main.async {
                self.displayPredictions(text: observation.identifier)
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop // 進行餵食
        
        self.visionRequests = [request] // 拿到結果
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:]) // 將拿到的結果左右反轉
        
        DispatchQueue.global().async {
            try! imageRequestHandler.perform(self.visionRequests) //處理所有的結果
        }
    }
    
    //    展示預測的結果
    func displayPredictions(text: String){
        
        let node = createText(text: text)
        
        // 把模型展示在我們點擊作用的當前位置（中央）
        node.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x,
                                   self.hitTestResult.worldTransform.columns.3.y,
                                   self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(node) // 把ＡＲ結果展示出來
        
    }
    
    //    制作結果ＡＲ原点跟底座
    func createText(text: String) -> SCNNode {
        let parentNode = SCNNode()
        
        //        底座
        let sphere = SCNSphere(radius: 0.01) // 1 cm 的小球几何形狀
        
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.orange //整個小球都是橘色的
        sphere.firstMaterial = sphereMaterial
        
        let sphereNode = SCNNode(geometry: sphere) // 創建了一個球狀的节点
        
        
        //        文字
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        textGeo.firstMaterial?.diffuse.contents = UIColor.orange
        textGeo.firstMaterial?.specular.contents = UIColor.white
        textGeo.firstMaterial?.isDoubleSided = true
        textGeo.font = UIFont(name: "Futura", size: 0.15)
        
        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(textNode)
        
        return parentNode
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
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
}

