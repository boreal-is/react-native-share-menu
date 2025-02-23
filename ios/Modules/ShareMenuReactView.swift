//
//  ShareMenuReactView.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 28/07/2020.
//

import MobileCoreServices
import Contacts

@objc(ShareMenuReactView)
public class ShareMenuReactView: NSObject {
    static var viewDelegate: ReactShareViewDelegate?

    @objc
    static public func requiresMainQueueSetup() -> Bool {
        return false
    }

    public static func attachViewDelegate(_ delegate: ReactShareViewDelegate!) {
        ShareMenuReactView.viewDelegate = delegate
    }

    public static func detachViewDelegate() {
        ShareMenuReactView.viewDelegate = nil
    }

    @objc(dismissExtension:)
    func dismissExtension(_ error: String?) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        if error != nil {
            let exception = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: DISMISS_SHARE_EXTENSION_WITH_ERROR_CODE,
                userInfo: ["error": error!]
            )
            extensionContext.cancelRequest(withError: exception)
            return
        }

        extensionContext.completeRequest(returningItems: [], completionHandler: nil)
    }

    @objc
    func openApp() {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        viewDelegate.openApp()
    }

    @objc(continueInApp:)
    func continueInApp(_ extraData: [String:Any]?) {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        let extensionContext = viewDelegate.loadExtensionContext()

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            print("Error: \(COULD_NOT_FIND_ITEM_ERROR)")
            return
        }

        viewDelegate.continueInApp(with: item, and: extraData)
    }

    @objc(data:reject:)
    func data(_
            resolve: @escaping RCTPromiseResolveBlock,
            reject: @escaping RCTPromiseRejectBlock) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        extractDataFromContext(context: extensionContext) { (data, mimeType, error) in
            guard (error == nil) else {
                reject("error", error?.description, nil)
                return
            }

            resolve([MIME_TYPE_KEY: mimeType, DATA_KEY: data])
        }
    }

    func extractDataFromContext(context: NSExtensionContext, withCallback callback: @escaping (String?, String?, NSException?) -> Void) {
        let item:NSExtensionItem! = context.inputItems.first as? NSExtensionItem
        let attachments:[AnyObject]! = item.attachments

        var urlProvider:NSItemProvider! = nil
        var imageProvider:NSItemProvider! = nil
        var textProvider:NSItemProvider! = nil
        var dataProvider:NSItemProvider! = nil
        var vcardProvider:NSItemProvider! = nil

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                urlProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeVCard as String){
                vcardProvider = provider as? NSItemProvider
                break
            }
            else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                textProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                imageProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                dataProvider = provider as? NSItemProvider
                break
            }
        }

        if (urlProvider != nil) {
            urlProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                let url: URL! = item as? URL

                callback(url.absoluteString, "text/plain", nil)
            }
        } else if (imageProvider != nil) {
            imageProvider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                let imageUrl: URL! = item as? URL

                if (imageUrl != nil) {
                    if let imageData = try? Data(contentsOf: imageUrl) {
                        callback(imageUrl.absoluteString, self.extractMimeType(from: imageUrl), nil)
                    }
                } else {
                    let image: UIImage! = item as? UIImage

                    if (image != nil) {
                        let imageData: Data! = image.pngData();

                        // Creating temporary URL for image data (UIImage)
                        guard let imageURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TemporaryScreenshot.png") else {
                            return
                        }

                        do {
                            // Writing the image to the URL
                            try imageData.write(to: imageURL)

                            callback(imageURL.absoluteString, imageURL.extractMimeType(), nil)
                        } catch {
                            callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"Can't load image", userInfo:nil))
                        }
                    }
                }
            }
        } else if (textProvider != nil) {
            textProvider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (item, error) in
                let text:String! = item as? String

                callback(text, "text/plain", nil)
            }
        }  else if (dataProvider != nil) {
            dataProvider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { (item, error) in
                let url: URL! = item as? URL

                callback(url.absoluteString, self.extractMimeType(from: url), nil)
            }
        } else if (vcardProvider != nil) {
            vcardProvider.loadItem(forTypeIdentifier: kUTTypeVCard as String, options: nil, completionHandler: {(item, error) in
                do {
                    let contactData = try CNContactVCardSerialization.contacts(with: item as! Data);
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
                      return;
                    }
                    let vCardData = String(data: json, encoding: String.Encoding.utf8);
                    callback(vCardData, "application/json", nil);
                } catch {
                  callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"couldn't serialize vcard data", userInfo:nil))
                }
            })
        } else {
            callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"couldn't find provider", userInfo:nil))
        }
    }

    func extractMimeType(from url: URL) -> String {
      let fileExtension: CFString = url.pathExtension as CFString
      guard let extUTI = UTTypeCreatePreferredIdentifierForTag(
              kUTTagClassFilenameExtension,
              fileExtension,
              nil
      )?.takeUnretainedValue() else { return "" }

      guard let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)
      else { return "" }

      return mimeUTI.takeUnretainedValue() as String
    }
}
