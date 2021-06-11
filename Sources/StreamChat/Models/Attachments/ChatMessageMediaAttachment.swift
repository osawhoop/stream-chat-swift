//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation

/// A type alias for attachment with `MediaAttachmentPayload` payload type.
///
/// The `ChatMessageMediaAttachment` attachment will be added to the message automatically
/// if the message was sent with attached `AnyAttachmentPayload` created with
/// local URL and `.media` attachment type.
public typealias ChatMessageMediaAttachment = _ChatMessageAttachment<MediaAttachmentPayload>

/// Represents a payload for attachments with `.media` type.
public struct MediaAttachmentPayload: AttachmentPayload {
    /// An attachment type all `MediaAttachmentPayload` instances conform to. Is set to `.media`.
    public static let type: AttachmentType = .media

    /// A title, usually the name of the video.
    public let title: String?
    /// A link to the video.
    public internal(set) var assetURL: URL
    /// The video itself.
    public let file: AttachmentFile
}

extension MediaAttachmentPayload: Equatable {}

// MARK: - Encodable

extension MediaAttachmentPayload: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AttachmentCodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(assetURL, forKey: .assetURL)
        try file.encode(to: encoder)
    }
}

// MARK: - Decodable

extension MediaAttachmentPayload: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AttachmentCodingKeys.self)

        guard
            let assetURL = try container
            .decodeIfPresent(String.self, forKey: .assetURL)?
            .attachmentFixedURL
        else {
            throw ClientError.AttachmentDecoding("Media attachment must contain `assetURL`")
        }

        self.init(
            title: try container.decodeIfPresent(String.self, forKey: .title),
            assetURL: assetURL,
            file: try AttachmentFile(from: decoder)
        )
    }
}
