//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import AVKit
import StreamChat
import UIKit

public typealias VideoPlaybackView = _VideoPlaybackView<NoExtraData>

open class _VideoPlaybackView<ExtraData: ExtraDataTypes>: _View, ComponentsProvider {
    public struct Content {
        public enum VideoState {
            case playing
            case paused
            case loading
        }
        
        public var videoDuration: TimeInterval
        public var videoState: VideoState
        public var playingProgress: Double
        
        public var currentTime: TimeInterval {
            playingProgress * videoDuration
        }
        
        public init(
            videoDuration: TimeInterval,
            videoState: VideoState,
            playingProgress: Double
        ) {
            self.videoDuration = videoDuration
            self.videoState = videoState
            self.playingProgress = playingProgress
        }
        
        public static var initial: Self {
            .init(
                videoDuration: 0,
                videoState: .loading,
                playingProgress: 0
            )
        }
    }
    
    private var playerTimeChagesObserver: Any?
    private var playerStatusObserver: NSKeyValueObservation?
    private var playerItemObserver: NSKeyValueObservation?
    private var itemDurationObserver: NSKeyValueObservation?
    private var itemEndPlayingObserver: Any?
    
    open var content: Content = .initial {
        didSet { updateContentIfNeeded() }
    }

    open weak var player: AVPlayer? {
        didSet {
            guard oldValue != player else { return }
            
            unsubscribeFromPlayerNotifications(oldValue)
            content = .initial
            subscribeToPlayerNotifications()
            
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    func unsubscribeFromPlayerNotifications(_ player: AVPlayer?) {
        if let observer = playerTimeChagesObserver {
            player?.removeTimeObserver(observer)
            playerTimeChagesObserver = nil
        }
        
        playerStatusObserver = nil
        playerItemObserver = nil
        
        if let observer = itemEndPlayingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        itemDurationObserver = nil
    }
    
    func subscribeToPlayerNotifications() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeChagesObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let currentItem = self?.player?.currentItem else { return }
            
            self?.content.playingProgress = time.seconds / currentItem.duration.seconds
        }
        
        playerStatusObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            guard let self = self else { return }

            switch player.timeControlStatus {
            case .playing:
                self.content.videoState = .playing
            case .paused:
                self.content.videoState = .paused
            default:
                self.content.videoState = .loading
            }
        }
        
        playerItemObserver = player.observe(\.currentItem, options: [.new, .initial]) { [weak self] player, _ in
            guard let self = self else { return }
            
            self.content.videoDuration = 0
            self.itemDurationObserver = player.currentItem?.observe(\.duration, options: [.new, .initial]) { [weak self] item, _ in
                self?.content.videoDuration = item.duration.isNumeric ? item.duration.seconds : 0
            }
            
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleItemDidPlayToEndTime),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
    }
    
    open private(set) lazy var loadingIndicator = components
        .loadingIndicator.init()
        .withoutAutoresizingMaskConstraints
    
    open private(set) lazy var playPauseButton = UIButton()
        .withoutAutoresizingMaskConstraints
    
    open private(set) lazy var timestampLabel = UILabel()
        .withoutAutoresizingMaskConstraints
        .withAdjustingFontForContentSizeCategory
        .withBidirectionalLanguagesSupport
    
    open private(set) lazy var durationLabel = UILabel()
        .withoutAutoresizingMaskConstraints
        .withAdjustingFontForContentSizeCategory
        .withBidirectionalLanguagesSupport
    
    open private(set) lazy var timeSlider = UISlider()
        .withoutAutoresizingMaskConstraints
    
    open private(set) lazy var rootContainer = ContainerStackView(axis: .vertical)
        .withoutAutoresizingMaskConstraints
    
    override open func setUp() {
        super.setUp()
        
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.addTarget(self, action: #selector(timeSliderDidChange), for: .valueChanged)
        
        playPauseButton.addTarget(self, action: #selector(handleTapOnPlayPauseButton), for: .touchUpInside)
    }
    
    override open func setUpLayout() {
        super.setUpLayout()
                
        let bottomContainer = UIView().withoutAutoresizingMaskConstraints
        
        bottomContainer.addSubview(timestampLabel)
        timestampLabel.pin(anchors: [.leading, .top, .bottom], to: bottomContainer)
        
        bottomContainer.addSubview(playPauseButton)
        playPauseButton.pin(anchors: [.centerX, .centerY], to: bottomContainer)
        
        bottomContainer.addSubview(loadingIndicator)
        loadingIndicator.pin(anchors: [.centerX, .centerY], to: bottomContainer)

        bottomContainer.addSubview(durationLabel)
        durationLabel.pin(anchors: [.trailing, .top, .bottom], to: bottomContainer)
        
        addSubview(rootContainer)
        rootContainer.pin(to: self)
        rootContainer.addArrangedSubview(timeSlider, respectsLayoutMargins: true)
        rootContainer.addArrangedSubview(bottomContainer, respectsLayoutMargins: true)
    }
    
    override open func setUpAppearance() {
        super.setUpAppearance()
        
        playPauseButton.setTitleColor(.black, for: .normal)
        timestampLabel.text = DateComponentsFormatter.videoDuration.string(from: 0)
        durationLabel.text = DateComponentsFormatter.videoDuration.string(from: 0)
    }
    
    override open func updateContent() {
        super.updateContent()
        
        timeSlider.value = .init(content.playingProgress)
        timestampLabel.text = DateComponentsFormatter.videoDuration.string(from: content.currentTime)
        durationLabel.text = DateComponentsFormatter.videoDuration.string(from: content.videoDuration)
        
        switch content.videoState {
        case .playing:
            playPauseButton.isHidden = false
            playPauseButton.setTitle("Pause", for: .normal)
            loadingIndicator.isHidden = true
        case .paused:
            playPauseButton.isHidden = false
            playPauseButton.setTitle("Play", for: .normal)
            loadingIndicator.isHidden = true
        case .loading:
            playPauseButton.isHidden = true
            loadingIndicator.isHidden = false
        }
    }
    
    // MARK: - Actions
    
    @objc
    open func timeSliderDidChange(_ sender: UISlider, event: UIEvent) {
        switch event.allTouches?.first?.phase {
        case .began:
            player?.pause()
        case .moved:
            let duration = player?.currentItem?.duration.seconds ?? 0
            let time = CMTime(seconds: duration * .init(sender.value), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        case .ended, .cancelled:
            player?.play()
        default:
            break
        }
    }
    
    @objc
    open func handleItemDidPlayToEndTime(_ notification: NSNotification) {
        player?.seek(to: .zero)
    }
    
    @objc
    open func handleTapOnPlayPauseButton() {
        switch player?.timeControlStatus {
        case .paused:
            player?.play()
        case .playing:
            player?.pause()
        default:
            break
        }
    }
    
    deinit {
        unsubscribeFromPlayerNotifications(player)
    }
}
