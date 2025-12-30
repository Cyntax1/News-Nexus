import Foundation
import UserNotifications
import CoreLocation
import OSLog

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, CLLocationManagerDelegate {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: "com.nexus.news", category: "Notifications")
    private let notificationCenter = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    
    @Published var isAuthorizedForNotifications = false
    @Published var isAuthorizedForLocation = false
    @Published var userLocation: CLLocation?
    @Published var notificationSettings: UNNotificationSettings?
    
    private var localBreakingNewsTimer: Timer?
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // City-level accuracy is sufficient
        
        // Check notification status
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationSettings = settings
                self?.isAuthorizedForNotifications = settings.authorizationStatus == .authorized
            }
        }
        
        // Check location status
        DispatchQueue.main.async { [weak self] in
            self?.isAuthorizedForLocation = CLLocationManager.authorizationStatus() == .authorizedWhenInUse || 
                                           CLLocationManager.authorizationStatus() == .authorizedAlways
        }
    }
    
    // Request notification permissions
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.logger.debug("Notification permission granted")
                    self?.isAuthorizedForNotifications = true
                    self?.registerCategories()
                } else if let error = error {
                    self?.logger.error("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Register notification categories
    private func registerCategories() {
        // Breaking news category
        let breakingAction = UNNotificationAction(
            identifier: "VIEW_BREAKING", 
            title: "View Story",
            options: .foreground
        )
        
        let breakingCategory = UNNotificationCategory(
            identifier: "BREAKING_NEWS",
            actions: [breakingAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Local news category
        let localAction = UNNotificationAction(
            identifier: "VIEW_LOCAL", 
            title: "View Local News",
            options: .foreground
        )
        
        let localCategory = UNNotificationCategory(
            identifier: "LOCAL_NEWS",
            actions: [localAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([breakingCategory, localCategory])
    }
    
    // Request location permissions
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Start location updates
    func startLocationUpdates() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // Schedule a breaking news notification
    func scheduleBreakingNewsNotification(title: String, body: String, articleURL: String) {
        guard isAuthorizedForNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Breaking: \(title)"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "BREAKING_NEWS"
        content.userInfo = ["url": articleURL]
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "breaking-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Error scheduling breaking news notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule a local news notification based on user location
    func scheduleLocalNewsNotification(title: String, body: String, articleURL: String) {
        guard isAuthorizedForNotifications, isAuthorizedForLocation, let location = userLocation else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Local News: \(title)"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "LOCAL_NEWS"
        content.userInfo = ["url": articleURL, "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
        
        // Trigger after a short delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "local-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Error scheduling local news notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Start monitoring for local breaking news
    func startLocalBreakingNewsMonitoring() {
        stopLocalBreakingNewsMonitoring()
        
        // Check every 15 minutes for local breaking news
        localBreakingNewsTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.checkForLocalBreakingNews()
        }
    }
    
    // Stop monitoring for local breaking news
    func stopLocalBreakingNewsMonitoring() {
        localBreakingNewsTimer?.invalidate()
        localBreakingNewsTimer = nil
    }
    
    // Check for local breaking news based on user location
    private func checkForLocalBreakingNews() {
        guard let location = userLocation else { return }
        
        // In a real app, this would make an API call to check for breaking news
        // near the user's location using the coordinates
        
        logger.debug("Checking for breaking news near location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // For now, we're just simulating this functionality
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_BREAKING", "VIEW_LOCAL":
            if let urlString = userInfo["url"] as? String, let url = URL(string: urlString) {
                // In a real app, you'd navigate to the article
                logger.debug("Should open URL: \(url)")
                
                // Post a notification that the app can observe to navigate to the article
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenArticleURL"),
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
            logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.isAuthorizedForLocation = status == .authorizedWhenInUse || status == .authorizedAlways
            
            if self?.isAuthorizedForLocation == true {
                self?.startLocationUpdates()
            }
        }
    }
} 