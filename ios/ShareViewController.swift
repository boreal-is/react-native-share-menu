//
//  ShareViewController.swift
//  RNShareMenu
//
//  DO NOT EDIT THIS FILE. IT WILL BE OVERRIDEN BY NPM OR YARN.
//
//  Created by Gustavo Parreira on 26/07/2020.
//

import MobileCoreServices
import UIKit
import Social
import RNShareMenu
import Contacts
//⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
//⚠️                                                                 ⚠️
//⚠️ To bring back the pop up when sharing follow the warning sign   ⚠️
//⚠️               PS: check in info.plist also                      ⚠️
//⚠️                                                                 ⚠️
//⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️


enum DataType {
  case VCARD, TEXT, DOCUMENTS
}

//⚠️ To have a post/send (pop up before choosing or not to open the app)change every ⚠️ to the old value
//UIViewController -> SLComposeServiceViewController
class ShareViewController: UIViewController {
  var hostAppId: String?
  var hostAppUrlScheme: String?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let hostAppId = Bundle.main.object(forInfoDictionaryKey: HOST_APP_IDENTIFIER_INFO_PLIST_KEY) as? String {
      self.hostAppId = hostAppId
    } else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
    }
    
    if let hostAppUrlScheme = Bundle.main.object(forInfoDictionaryKey: HOST_URL_SCHEME_INFO_PLIST_KEY) as? String {
      self.hostAppUrlScheme = hostAppUrlScheme
    } else {
      print("Error: \(NO_INFO_PLIST_URL_SCHEME_ERROR)")
    }
  }
  //⚠️ To have a post/send (pop up before choosing or not to open the app)change every ⚠️ to the old value
  //remove this function
  override func viewWillAppear(_ animated: Bool) {
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
      cancelRequest()
      return
    }
    handlePost(item)
  }

  //⚠️ To have a post/send (pop up before choosing or not to open the app)change every ⚠️ to the old value
  //uncomment these functions: isContentValid, didSelectPost and configurationItems
//    override func isContentValid() -> Bool {
//        // Do validation of contentText and/or NSExtensionContext attachments here
//        return true
//    }
//
//    override func didSelectPost() {
//        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
//      guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
//        cancelRequest()
//        return
//      }
//
//      handlePost(item)
//    }
//
//    override func configurationItems() -> [Any]! {
//        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
//        return []
//    }

  func handlePost(_ item: NSExtensionItem, extraData: [String:Any]? = nil) {
    if ((item.attachments?.first) == nil) {
      cancelRequest()
      return
    }

    if let data = extraData {
      storeExtraData(data)
    } else {
      removeExtraData()
    }
    let group = DispatchGroup();
    for provider in item.attachments! {
      group.enter();
      if provider.isVCard {
        storeVCard(withProvider: provider, group: group)
      } else if provider.isText {
        storeText(withProvider: provider, group: group)
      } else if provider.isURL {
        storeUrl(withProvider: provider, group: group)
      } else {
        storeFile(withProvider: provider, group: group)
      }
    }
    
    group.notify(queue: .main) {
      self.openHostApp()
    }
  }

  func storeExtraData(_ data: [String:Any]) {
    guard let hostAppId = self.hostAppId else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
      self.exit(withError: NO_APP_GROUP_ERROR)
      return
    }
    userDefaults.set(data, forKey: USER_DEFAULTS_EXTRA_DATA_KEY)
    userDefaults.synchronize()
  }

  func removeExtraData() {
    guard let hostAppId = self.hostAppId else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
      self.exit(withError: NO_APP_GROUP_ERROR)
      return
    }
    userDefaults.removeObject(forKey: USER_DEFAULTS_EXTRA_DATA_KEY)
    userDefaults.synchronize()
  }
  
  func addToUserDefaults(_ value: String, _ mimeType: String, _ dataType: DataType){
    guard let hostAppId = self.hostAppId else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
      self.exit(withError: NO_APP_GROUP_ERROR)
      return
    }
    if dataType == DataType.TEXT {
      userDefaults.set([TEXT_KEY: [DATA_KEY: value, MIME_TYPE_KEY: mimeType]], forKey: USER_DEFAULTS_KEY)
    } else if dataType == DataType.VCARD {
      userDefaults.set([VCARD_KEY: [DATA_KEY: value, MIME_TYPE_KEY: mimeType]], forKey: USER_DEFAULTS_KEY)
    } else if dataType == DataType.DOCUMENTS{
      let userDefaultData: [String:Any] = userDefaults.object(forKey: USER_DEFAULTS_KEY) as? [String:Any] ?? [:];
      if userDefaultData.isEmpty {
        var documents = [Any]()
        documents.append([URL_KEY: value, MIME_TYPE_KEY: mimeType])
        userDefaults.set([DOCUMENTS_KEY: documents], forKey: USER_DEFAULTS_KEY)
      } else {
        var documents = userDefaultData[DOCUMENTS_KEY] as? [Any] ?? []
        documents.append([URL_KEY: value, MIME_TYPE_KEY: mimeType])
        userDefaults.set([DOCUMENTS_KEY: documents], forKey: USER_DEFAULTS_KEY)
      }
    }
    userDefaults.synchronize()
  }
  
  func storeVCard(withProvider provider: NSItemProvider, group: DispatchGroup) {
    provider.loadItem(forTypeIdentifier: kUTTypeVCard as String, options: nil) { (data, error) in
      do {
        guard (error == nil) else {
          self.exit(withError: error.debugDescription)
          return
        }
        guard let dataToSerialize = data as? Data else {
          self.storeFile(withProvider: provider, group: group);
          return
        }
        
        let contactData = try CNContactVCardSerialization.contacts(with: dataToSerialize);
        var contact = [String:Any]()
        contact["email"] = contactData.first?.emailAddresses.first?.value;
        contact["firstName"] = contactData.first?.givenName;
        contact["lastName"] = contactData.first?.familyName;
        contact["phone"] = contactData.first?.phoneNumbers.first?.value.stringValue;
        contact["organization"] = contactData.first?.organizationName;
        if(contactData.first?.postalAddresses.first?.value != nil){
          contact["address"] = CNPostalAddressFormatter.string(from: contactData.first!.postalAddresses.first!.value, style: .mailingAddress);
        }
        if(contactData.first!.imageDataAvailable){
          // Creating temporary URL for image data (UIImage)
          guard let imageUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TemporaryScreenshot.png") else {
            return
          };
          // Writing the image to the URL
          try contactData.first!.imageData!.write(to: imageUrl)
          contact["photoPath"] = imageUrl.absoluteString;
          contact["photoMime"] = "image/png";
        }
        guard let json = try? JSONSerialization.data(withJSONObject: contact, options: []) else {
          self.exit(withError: "Can't serialized item as JSON");
          return;
        }
        let vCardData = String(data: json, encoding: String.Encoding.utf8);
        
        self.addToUserDefaults(vCardData!, "application/json", DataType.VCARD)
        group.leave()
      } catch {
        self.exit(withError: "Sending VCard data to application failed");
        group.leave()
      }
    }
  }
  
  func storeText(withProvider provider: NSItemProvider,  group: DispatchGroup) {
    provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (data, error) in
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      guard let text = data as? String else {
        self.exit(withError: COULD_NOT_FIND_STRING_ERROR)
        return
      }
      self.addToUserDefaults(text, "text/plain", DataType.TEXT)
      group.leave()
    }
  }
  
  func storeUrl(withProvider provider: NSItemProvider, group: DispatchGroup) {
    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (data, error) in
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      guard let url = data as? URL else {
        self.exit(withError: COULD_NOT_FIND_URL_ERROR)
        return
      }
      self.addToUserDefaults(url.absoluteString, "text/plain", DataType.TEXT)
      group.leave()
    }
  }
  
  func handleFolder(withProvider provider: NSItemProvider, group: DispatchGroup) {
    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (data, error) in
      do {
        guard (error == nil) else {
          self.exit(withError: error.debugDescription)
          return
        }
        guard let url = data as? URL else {
          self.exit(withError: COULD_NOT_FIND_URL_ERROR)
          return
        }
        let items = try FileManager.default.contentsOfDirectory(at: url.absoluteURL, includingPropertiesForKeys: [.isDirectoryKey])
        for item in items {
          let mimeType = item.extractMimeType()
          self.addToUserDefaults(item.absoluteString, mimeType, DataType.DOCUMENTS)
        }
        group.leave()
      } catch {
        self.exit(withError: "Can't handle this file / folder")
        group.leave()
      }
    }
  }
  
  func storeFile(withProvider provider: NSItemProvider, group: DispatchGroup) {
    provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { (data, error) in
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }

      guard let url = data as? URL else {
        self.handleFolder(withProvider: provider, group: group)
        return
      }
      guard let hostAppId = self.hostAppId else {
        print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
        return
      }
      guard let groupFileManagerContainer = FileManager.default
              .containerURL(forSecurityApplicationGroupIdentifier: "group.\(hostAppId)")
      else {
        self.exit(withError: NO_APP_GROUP_ERROR)
        return
      }
      let mimeType = url.extractMimeType()
      let fileName = (url.absoluteString as NSString).lastPathComponent;
      let filePath = groupFileManagerContainer.appendingPathComponent("\(fileName)")
      
      guard self.moveFileToDisk(from: url, to: filePath) else {
        self.exit(withError: COULD_NOT_SAVE_FILE_ERROR)
        return
      }
      self.addToUserDefaults(filePath.absoluteString, mimeType, DataType.DOCUMENTS)
      group.leave()
    }
  }

  func moveFileToDisk(from srcUrl: URL, to destUrl: URL) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: destUrl.path) {
        try FileManager.default.removeItem(at: destUrl)
      }
      try FileManager.default.copyItem(at: srcUrl, to: destUrl)
    } catch (let error) {
      print("Could not save file from \(srcUrl) to \(destUrl): \(error)")
      return false
    }
    
    return true
  }
  
  func exit(withError error: String) {
    print("Error: \(error)")
    cancelRequest()
  }
  
  internal func openHostApp() {
    guard let urlScheme = self.hostAppUrlScheme else {
      exit(withError: NO_INFO_PLIST_URL_SCHEME_ERROR)
      return
    }
    
    let url = URL(string: urlScheme)
    let selectorOpenURL = sel_registerName("openURL:")
    var responder: UIResponder? = self
    
    while responder != nil {
      if responder?.responds(to: selectorOpenURL) == true {
        responder?.perform(selectorOpenURL, with: url)
      }
      responder = responder!.next
    }
    
    completeRequest()
  }
  
  func completeRequest() {
    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
  }
  
  func cancelRequest() {
    extensionContext!.cancelRequest(withError: NSError())
  }

}
