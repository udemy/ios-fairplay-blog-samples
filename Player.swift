let resourceLoader: AVAssetResourceLoaderDelegate = SampleResourceLoaderDelegate()
let resourceLoaderQueue = DispatchQueue(label: "fairplay.queue")

let player: AVPlayer = .init()
let asset: AVURLAsset = .init(url: url, options: options)
// Set the resource loader delegate to this class. The `resourceLoader`'s delegate will be
// triggered when FairPlay handling is required.
// If this is not a DRM protected video path, delegate will not get triggered
asset.resourceLoader.setDelegate(resourceLoader, queue: resourceLoaderQueue)
let newItem: AVPlayerItem = .init(asset: asset)
observePlayerItemProperties(for: newItem)
// Load player item to AVPlayer
player.replaceCurrentItem(with: newItem)
