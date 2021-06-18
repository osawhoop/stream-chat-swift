//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatUI
import StreamChat

extension ChatClient {
    /// The singleton instance of `ChatClient`
    static let shared: ChatClient = {
        Components.default.messageComposerVC = CustomComposer.self
        let config = ChatClientConfig(apiKey: APIKey("q95x9hkbyd6p"))
        return ChatClient(
            config: config,
            tokenProvider: .static(
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2lsdmlhIn0.jHi2vjKoF02P9lOog0kDVhsIrGFjuWJqZelX5capR30"
            )
        )
    }()
}

final class CustomComposer: ComposerVC {
    
    lazy var informationLabel: UILabel = {
       let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "This is label"
        label.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return label
    }()
    
    override func setUpLayout() {
        super.setUpLayout()
        view.addSubview(informationLabel)
      
        NSLayoutConstraint.activate([
            informationLabel.topAnchor.constraint(equalTo: composerView.bottomAnchor),
            informationLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            informationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            informationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

class ChildViewController: ChatMessageListVC {
    override func viewDidLoad() {
        channelController = ChatClient.shared.channelController(for: ChannelId(type: .messaging, id: "channel-ex-slack-5-1"))
        super.viewDidLoad()
    }
}


class ViewController: UIViewController  {}
class OtherViewController: UIViewController {}
