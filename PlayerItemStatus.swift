private func observePlayerItemProperties(for item: AVPlayerItem) {
    item.observe(\.status, changeHandler: self.onStatusObserverChanged)
}

private func onStatusObserverChanged(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<AVPlayerItem.Status>) {
    guard playerItem.status != .failed else {
        if let error = playerItem.error as? Error {
            // DRM Errors handled here
        }
        return
    }
    ....
}
