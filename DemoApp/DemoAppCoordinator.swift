//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatUI
import UIKit

final class DemoAppCoordinator {
    private var connectionController: ChatConnectionController?
    private let navigationController: UINavigationController
    private let connectionDelegate: BannerShowingConnectionDelegate
    
    init(navigationController: UINavigationController) {
        // Since log is first touched in `BannerShowingConnectionDelegate`,
        // we need to set log level here
        LogConfig.level = .warning
        
        self.navigationController = navigationController
        connectionDelegate = BannerShowingConnectionDelegate(
            showUnder: navigationController.navigationBar
        )
        injectActions()
    }
    
    func presentChat(userCredentials: UserCredentials) {
        // Create a token
        let token = try! Token(rawValue: userCredentials.token)
        
        // Create client
        let config = ChatClientConfig(apiKey: .init(userCredentials.apiKey))
        let client = ChatClient(config: config, tokenProvider: .static(token))
        
        // Config
        Components.default.channelListRouter = DemoChatChannelListRouter.self
        Components.default.messageComposerVC = CustomComposerVC.self
        Appearance.default.images.openAttachments = UIImage(systemName: "plus")!
        
        // Channels with the current user
        let controller = client.channelListController(query: .init(filter: .containMembers(userIds: [userCredentials.id])))
        let chatList = ChatChannelListVC()
        chatList.controller = controller
        
        connectionController = client.connectionController()
        connectionController?.delegate = connectionDelegate
        
        navigationController.viewControllers = [chatList]
        navigationController.isNavigationBarHidden = false
        
        let window = navigationController.view.window!
        
        UIView.transition(with: window, duration: 0.3, options: .transitionFlipFromRight, animations: {
            window.rootViewController = self.navigationController
        })
    }
    
    private func injectActions() {
        if let loginViewController = navigationController.topViewController as? LoginViewController {
            loginViewController.didRequestChatPresentation = { [weak self] in
                self?.presentChat(userCredentials: $0)
            }
        }
    }
}

// Custom Contacts

import ContactsUI

class CustomComposerVC: ComposerVC {
    // Adding the new contacts picker action
    override var attachmentsPickerActions: [UIAlertAction] {
        let contactsAction = UIAlertAction(
            title: "Contacts",
            style: .default,
            handler: { [weak self] _ in
                self?.showContactPicker()
            }
        )
        return super.attachmentsPickerActions + [contactsAction]
    }

    // Helper to show the contact picker
    func showContactPicker() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        present(contactPicker, animated: true)
    }
}

extension CustomComposerVC: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        let contactAttachments = contacts
            .map { contact in
                ContactAttachmentPayload(
                    name: "\(contact.givenName) \(contact.familyName)",
                    phoneNumber: contact.phoneNumbers.first?.value.stringValue ?? ""
                )
            }
            .map(AnyAttachmentPayload.init)

        content.attachments.append(contentsOf: contactAttachments)
    }
}

// Custom attachment
extension AttachmentType {
    static let contact = Self(rawValue: "contact")
}

struct ContactAttachmentPayload: AttachmentPayload {
    static let type: AttachmentType = .contact

    let name: String
    let phoneNumber: String
}

// Composer preview for custom attachment
extension ContactAttachmentPayload: AttachmentPreviewProvider {
    static let preferredAxis: NSLayoutConstraint.Axis = .vertical

    func previewView<ExtraData: ExtraDataTypes>(components: _Components<ExtraData>) -> UIView {
        let preview = ContactAttachmentView()
        preview.content = self
        return preview
    }
}

class ContactAttachmentView: _View, AppearanceProvider {
    var content: ContactAttachmentPayload? {
        didSet { updateContentIfNeeded() }
    }

    let contactNameLabel = UILabel()
    let contactPhoneNumberLabel = UILabel()
    let contactStackView = UIStackView()

    override func setUpAppearance() {
        super.setUpAppearance()

        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 15
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = appearance.colorPalette.border.cgColor
        
        contactNameLabel.textColor = appearance.colorPalette.subtitleText
        contactNameLabel.font = appearance.fonts.subheadlineBold

        contactPhoneNumberLabel.textColor = appearance.colorPalette.text
        contactPhoneNumberLabel.font = appearance.fonts.bodyBold

        contactStackView.axis = .vertical
    }

    override func setUpLayout() {
        super.setUpLayout()

        addSubview(contactStackView)
        contactStackView.addArrangedSubview(contactNameLabel)
        contactStackView.addArrangedSubview(contactPhoneNumberLabel)
        contactStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),
            contactStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            contactStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            contactStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            contactStackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    override func updateContent() {
        super.updateContent()

        contactNameLabel.text = content?.name
        contactPhoneNumberLabel.text = content?.phoneNumber
    }
}
