import UIKit
import WebKit
import CoreLocation

/// A MapView displays interactive 3d map.
public class MapView : UIView {

	enum Const {
		static let mapMinZoom: Double = 2
		static let mapMaxZoom: Double = 20
		static let mapMinPitch: Double = 0
		static let mapMaxPitch: Double = 60

		static let mapDefaultZoom: Double = 2
		static let mapDefaultRotation: Double = 0
		static let mapDefaultPitch: Double = 0
		static let mapDefaultMinZoom: Double = 2
		static let mapDefaultMaxZoom: Double = 20
		static let mapDefaultMinPitch: Double = 0
		static let mapDefaultMaxPitch: Double = 45
		static let mapDefaultCenter = CLLocationCoordinate2D(latitude: 55.750574, longitude: 37.618317)
	}

	/// Optional methods that you use to receive map-related update messages.
	public weak var delegate: MapViewDelegate?

	private var objects: [String: MapObject] = [:]

	private var jsExecutor: JSExecutorProtocol?

	private var _mapCenter = Const.mapDefaultCenter
	private var _mapRotation: Double = Const.mapDefaultRotation

	private var _mapZoom: Double = Const.mapDefaultZoom
	private var _styleZoom: Double = Const.mapDefaultZoom
	private var _mapMinZoom: Double = Const.mapDefaultMinZoom
	private var _mapMaxZoom: Double = Const.mapDefaultMaxZoom

	private var _mapPitch: Double = Const.mapDefaultPitch
	private var _mapMinPitch: Double = Const.mapDefaultMinPitch
	private var _mapMaxPitch: Double = Const.mapDefaultMaxPitch

	// swiftlint:disable:next weak_delegate
	private let wkDelegate = WKDelegate()

	private lazy var js: JSBridge = {
		let js = JSBridge(executor: self.jsExecutor ?? self)
		js.delegate = self
		return js
	}()

	private lazy var webView: WKWebView = {
		let webConfiguration = WKWebViewConfiguration()
		webConfiguration.userContentController.add(self.js, name: self.js.messageHandlerName)
		webConfiguration.userContentController.add(self.js, name: self.js.errorHandlerName)
		let webView = WKWebView(frame: .zero, configuration: webConfiguration)
		webView.navigationDelegate = self.wkDelegate
		webView.uiDelegate = self.wkDelegate
		return webView
	}()

	private lazy var locationManager: UserLocationManager = {
		let manager = UserLocationManager()
		manager.delegate = self
		return manager
	}()

	/// Notifies of the map geographical center change.
	public var centerDidChange: ((CLLocationCoordinate2D) -> Void)?
	/// Notifies of the map zoom level change.
	public var zoomDidChange: ((Double) -> Void)?
	/// Notifies of the map rotation angle change.
	public var rotationDidChange: ((Double) -> Void)?
	/// Notifies of the map pitch angle change.
	public var pitchDidChange: ((Double) -> Void)?
	/// Notifies of the map click event.
	public var mapClick: ((CLLocationCoordinate2D) -> Void)?

	/// Creates the new instance of the MapView object.
	///
	/// - Parameter frame: Initial view frame
	public override init(
		frame: CGRect
	) {
		super.init(frame: frame)
		self.commonInit()
	}

	/// Creates the new instance of the MapView object.
	///
	/// - Parameter jsExecutor: Custom JS executor
	init(jsExecutor: JSExecutorProtocol) {
		super.init(frame: .zero)
		self.jsExecutor = jsExecutor
		self.commonInit()
	}

	/// Creates the new instance of the MapView object.
	///
	/// - Parameter aDecoder: NSCoder instance
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.commonInit()
	}

	private func commonInit() {
		if #available(iOS 11.0, *) {
			self.webView.scrollView.contentInsetAdjustmentBehavior = .never
		}
		self.addSubview(self.webView)
	}

	public override func layoutSubviews() {
		super.layoutSubviews()
		self.webView.frame = self.bounds
	}

	/// Gets or sets the geographical center of the map.
	public var mapCenter: CLLocationCoordinate2D {
		get {
			return _mapCenter
		}
		set {
			_mapCenter = newValue
			self.js.setMapCenter(newValue, completion: nil)
		}
	}

	/// Gets or sets the rotation angle of the map.
	public var mapRotation: Double {
		get {
			return _mapRotation
		}
		set {
			_mapRotation = newValue
			self.js.setMapRotation(newValue, completion: nil)
		}
	}

	/// Gets or sets the style zoom level of the map. Have priority over mapZoom
	public var styleZoom: Double {
		get {
			return _styleZoom
		}
		set {
			_styleZoom = newValue
			self.js.setStyleZoom(newValue)
		}
	}

	/// Gets or sets the zoom level of the map.
	public var mapZoom: Double {
		get {
			return _mapZoom
		}
		set {
			_mapZoom = max(newValue, _mapMinZoom)
			_mapZoom = min(_mapZoom, _mapMaxZoom)
			self.js.setMapZoom(_mapZoom)
		}
	}

	/// Returns the current map style zoom.
	public func getStyleZoom() -> Double {
		_styleZoom
	}

	/// Gets or sets the mininal zoom level of the map. This value can not be less than 2.
	public var mapMinZoom: Double {
		get {
			return _mapMinZoom
		}
		set {
			_mapMinZoom = max(newValue, Const.mapMinZoom)
			_mapMinZoom = min(_mapMinZoom, Const.mapMaxZoom)
			self.js.setMapMinZoom(_mapMinZoom, completion: nil)
		}
	}

	/// Gets or sets the maximal zoom level of the map. This value can not be greater than 20.
	public var mapMaxZoom: Double {
		get {
			return _mapMaxZoom
		}
		set {
			_mapMaxZoom = max(newValue, Const.mapMinZoom)
			_mapMaxZoom = min(_mapMaxZoom, Const.mapMaxZoom)
			self.js.setMapMaxZoom(_mapMaxZoom, completion: nil)
		}
	}

	/// Gets or sets the map pitch angle.
	public var mapPitch: Double {
		get {
			return _mapPitch
		}
		set {
			_mapPitch = max(newValue, _mapMinPitch)
			_mapPitch = min(_mapPitch, _mapMaxPitch)
			self.js.setMapPitch(_mapPitch, completion: nil)
		}
	}

	/// Gets or sets the maximal pitch angle of the map. This value can not be less than 0.
	public var mapMinPitch: Double {
		get {
			return _mapMinPitch
		}
		set {
			_mapMinPitch = max(newValue, Const.mapMinPitch)
			_mapMinPitch = min(_mapMinPitch, Const.mapMaxPitch)
			self.js.setMapMinPitch(newValue, completion: nil)
		}
	}

	/// Gets or sets the mininal pitch angle of the map. This value can not be greater than 60.
	public var mapMaxPitch: Double {
		get {
			return _mapMaxPitch
		}
		set {
			_mapMaxPitch = max(newValue, Const.mapMinPitch)
			_mapMaxPitch = min(_mapMaxPitch, Const.mapMaxPitch)
			self.js.setMapMaxPitch(newValue, completion: nil)
		}
	}

	/// Initializes and shows the map. Important: all manipulations with the map must be done
	/// after the completion handler of this method is executed.
	///
	/// - Parameters:
	///   - apiKey: Secret key.
	///   - center: Initial coordinates of the map center.
	///   - zoom: Initial map zoom level.
	///   - styleZoom: Initial map zoom level. Have priority over zoom and different. Formula: styleZoom = zoom + log2(1 / (2 * cos(latitude))
	///   - rotation: Initial map rotation angle.
	///   - pitch: Initial map pinch angle.
	///   - autoHideOSMCopyright: If true, the OSM copyright will be hidden after 5 seconds from the map initialization.
	///   - disableRotationByUserInteraction: Prevent users from rotating a map.
	///   - disablePitchByUserInteraction: Prevent users from pitching a map.
	///   - maxBounds: The map will be constrained to the given bounds, if set.
	///   - mapStyleId: The map style identifier. Use "c080bb6a-8134-4993-93a1-5b4d8c36a59b" for day, "e05ac437-fcc2-4845-ad74-b1de9ce07555" for night.
	///   - completion: Completion handler.
	public func show(
		apiKey: String,
		center: CLLocationCoordinate2D? = nil,
		zoom: Double? = nil,
		styleZoom: Double? = nil,
		rotation: Double? = nil,
		pitch: Double? = nil,
		autoHideOSMCopyright: Bool = false,
		disableRotationByUserInteraction: Bool = false,
		disablePitchByUserInteraction: Bool = false,
		maxBounds: GeographicalBounds? = nil,
		mapStyleId: String? = nil,
		completion: ((Error?) -> Void)? = nil
	) {
		if let center = center {
			_mapCenter = center
		}

		if let zoom = zoom {
			_mapZoom = max(zoom, _mapMinZoom)
			_mapZoom = min(_mapZoom, _mapMaxZoom)
		}

		if let styleZoom = styleZoom {
			_styleZoom = max(styleZoom, _mapMinZoom)
			_styleZoom = min(_styleZoom, _mapMaxZoom)
		}

		if let rotation = rotation {
			_mapRotation = rotation
		}

		if let pitch = pitch {
			_mapPitch = max(pitch, _mapMinPitch)
			_mapPitch = min(_mapPitch, _mapMaxPitch)
		}
		let shouldFetchZoom = zoom == nil

		self.loadHtml { [weak self] in
			self?.initializeMap(
				apiKey: apiKey,
				autoHideOSMCopyright: autoHideOSMCopyright,
				disableRotationByUserInteraction: disableRotationByUserInteraction,
				disablePitchByUserInteraction: disablePitchByUserInteraction,
				maxBounds: maxBounds,
				mapStyleId: mapStyleId,
				shouldFetchZoom: shouldFetchZoom
			) { error in
				completion?(error)
			}
		}
	}

	/// Zoomes the map in.
	public func zoomIn() {
		self.mapZoom = min(self.mapZoom + 1, self.mapMaxZoom)
	}

	/// Sets the map style zoom.
	/// - Parameters:
	///   - zoom: The desired style zoom.
	///   - options: Zoom animation options.
	public func setStyleZoom(
		_ zoom: Double,
		options: MapGL.AnimationOptions? = nil
	) {
		_styleZoom = zoom
		self.js.setStyleZoom(zoom, options: options)
	}

	/// Sets the map style by identifier and apply it to the map.
	/// - Parameters:
	///   - id: uuid of the style.
	public func setStyle(
		by id: String
	) {
		self.js.setStyle(by: id)
	}

	/// Sets the map style zoom.
	/// - Parameters:
	///   - zoom: The desired style zoom.
	///   - options: Zoom animation options.
	public func setZoom(
		_ zoom: Double,
		options: MapGL.AnimationOptions? = nil
	) {
		_mapZoom = zoom
		self.js.setMapZoom(zoom, options: options)
	}

	/// Zoomes the map out.
	public func zoomOut() {
		self.mapZoom = max(self.mapZoom - 1, self.mapMinZoom)
	}

	/// Returns the geographical bounds visible in the current map view.
	/// - Parameter completion: Completion handler.
	public func fetchGeographicalBounds(completion: @escaping (Result<GeographicalBounds, Error>) -> Void) {
		self.js.fetchGeographicalBounds(completion: completion)
	}

	private func loadHtml(completion: @escaping () -> Void) {
		self.webView.loadHTMLString(HTML.html, baseURL: nil)
		self.wkDelegate.onInitializeMap = {
			completion()
		}
	}

	private func initializeMap(
		apiKey: String,
		autoHideOSMCopyright: Bool = false,
		disableRotationByUserInteraction: Bool = false,
		disablePitchByUserInteraction: Bool = false,
		maxBounds: GeographicalBounds? = nil,
		mapStyleId: String? = nil,
		shouldFetchZoom: Bool,
		completion: @escaping ((Error?) -> Void)
	) {
		let options: JSOptionsDictionary = [
			"center": self.mapCenter,
			"maxZoom": self.mapMaxZoom,
			"minZoom": self.mapMinZoom,
			"zoom": self.mapZoom,
			"styleZoom": self.styleZoom,
			"maxPitch": self.mapMaxPitch,
			"minPitch": self.mapMinPitch,
			"pitch": self.mapPitch,
			"rotation": self.mapRotation,
			"zoomControl": false,
			"key": apiKey,
			"interactiveCopyright": false,
			"autoHideOSMCopyright": autoHideOSMCopyright,
			"preserveDrawingBuffer": true,
			"disableRotationByUserInteraction": disableRotationByUserInteraction,
			"disablePitchByUserInteraction": disablePitchByUserInteraction,
			"maxBounds": maxBounds,
			"style": mapStyleId,
		]

		self.js.initializeMap(options: options) { [weak self] result in
			guard let self = self else { return }
			switch result {
				case .success:
					self.centerDidChange?(self.mapCenter)
					self.rotationDidChange?(self.mapRotation)
					self.pitchDidChange?(self.mapPitch)
					if shouldFetchZoom {
						self.js.fetchMapZoom {
							if case .success(let zoom) = $0 {
								self._mapZoom = zoom
								self.zoomDidChange?(self.mapZoom)
							}
						}
					} else {
						self.zoomDidChange?(self.mapZoom)
					}
					completion(nil)
				case .failure(let error):
					completion(error)
			}
		}
	}

}

// MARK: - JSExecutorProtocol

extension MapView: JSExecutorProtocol {

	func evaluateJavaScript(_ javaScriptString: String, completion: ((Any?, Error?) -> Void)?) {
		self.webView.evaluateJavaScript(javaScriptString, completionHandler: completion)
	}
}

// MARK: - JSBridgeDelegate

extension MapView: JSBridgeDelegate {

	func js(_ js: JSBridge, mapCenterDidChange mapCenter: CLLocationCoordinate2D) {
		_mapCenter = mapCenter
		self.centerDidChange?(mapCenter)
	}

	func js(_ js: JSBridge, mapZoomDidChange mapZoom: Double) {
		_mapZoom = mapZoom
		self.zoomDidChange?(mapZoom)
	}

	func js(_ js: JSBridge, mapStyleZoomChanged mapZoom: Double) {
		_styleZoom = mapZoom
	}

	func js(_ js: JSBridge, mapRotationDidChange mapRotation: Double) {
		_mapRotation = mapRotation
		self.rotationDidChange?(mapRotation)
	}

	func js(_ js: JSBridge, mapPitchDidChange mapPitch: Double) {
		_mapPitch = mapPitch
		self.pitchDidChange?(mapPitch)
	}

	func js(_ js: JSBridge, didClickMapWithEvent event: MapClickEvent) {
		self.mapClick?(event.coordinate)
		self.delegate?.mapView?(self, didSelectCoordnates: event.coordinate)
		if let objectId = event.target?.id {
			self.delegate?.mapView?(self, didSelectObject: MapEntity(id: objectId))
		}
	}

	func js(_ js: JSBridge, didClickObjectWithId objectId: String) {
		if let object = self.objects[objectId] {
			self.delegate?.mapView?(self, didSelectObject: object)
		} else {
			assertionFailure()
		}
	}

	func js(_ js: JSBridge, didClickClusterWithId clusterId: String, markerIds: [String]) {
		if let cluster = self.objects[clusterId] as? Cluster {
			let markers = cluster.markers.filter { markerIds.contains($0.id) }
			self.delegate?.mapView?(self, didSelectMarkers: markers, in: cluster)
		} else {
			assertionFailure()
		}
	}

	func js(_ js: JSBridge, carRouteDidFinishWithId directionId: String, completionId: String, error: MapGLError?) {
		guard let direction = objects[directionId] as? Directions else {
			assertionFailure()
			return
		}
		var result: Result<Void, MapGLError> {
			if let error = error {
				return .failure(error)
			} else {
				return .success(())
			}
		}
		direction.invokeCompletion(with: completionId, result: result)
	}

}

// MARK: - IObjectDelegate

extension MapView: IObjectDelegate {
	func evaluateJS(_ js: String) {
		self.js.evaluateJS(js)
	}
}

// MARK: - Objects

extension MapView {

	/// Adds the given object to the map.
	///
	/// - Parameter object: MapObject to be added to the map.
	public func add(_ object: MapObject) {
		object.delegate = self
		self.objects[object.id] = object
		self.js.add(object, completion: nil)
	}

	/// Removes the given object to the map.
	/// - Parameter object: MapObject to be removed from map.
	public func remove(_ object: MapObject) {
		object.delegate = nil
		self.objects.removeValue(forKey: object.id)
		self.js.destroy(object)
	}

	/// Remove all objects from map
	public func removeAllObjects() {
		for object in self.objects.values {
			self.objects.removeValue(forKey: object.id)
			self.js.destroy(object)
		}
	}

	/// Select objects on map with given ids
	/// remove selection from all selected objeccts not in list
	/// - Parameter objectsIds: objects Ids to be selected
	public func setSelectedObjects(_ objectsIds: [String]) {
		self.js.setSelectedObjects(objectsIds)
	}

	/// Create a class that provides driving direction functionality.
	/// - Parameter apiKey: Your Directions API access key
	/// - Returns: A class that provides driving direction functionality.
	public func makeDirections(
		with apiKey: String
	) -> Directions {
		let directions = Directions(apiKey: apiKey)
		self.add(directions)
		return directions
	}
}

// MARK: - User Location

extension MapView {

	/// Gets the last location received.
	public var userLocation: CLLocation? {
		return self.locationManager.userLocation
	}

	/// Shows the user location on the map.
	/// - Parameter options: Options for location services.
	public func enableUserLocation(options: UserLocationOptions = UserLocationOptions()) {
		locationManager.enableUserLocation(options: options)
	}

	/// Stops displaying and updating the user location.
	public func disableUserLocation() {
		locationManager.disableUserLocation()
	}
}

// MARK: - UserLocationManagerDelegate

extension MapView: UserLocationManagerDelegate {
	func userLocationManager(_ manager: UserLocationManager, addUserLocationMarker marker: MapObject) {
		self.js.add(marker, completion: nil)
	}

	func userLocationManager(_ manager: UserLocationManager, removeUserLocationMarker marker: MapObject) {
		self.remove(marker)
	}

	func userLocationManager(_ manager: UserLocationManager, didUpdateUserLocation location: CLLocation?) {
		self.delegate?.mapView?(self, didUpdateUserLocation: location)
	}
}
