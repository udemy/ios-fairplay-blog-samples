let resourceLoader: AVAssetResourceLoaderDelegate = SampleResourceLoaderDelegate()
let resourceLoaderQueue = DispatchQueue(label: "fairplay.queue")
let downloadSession = AVAssetDownloadURLSession(...)
let bitrate = 500000

let urlAsset = AVURLAsset(url: requestURL, options: options)
// If this is not a DRM protected video path, delegate will not get triggered
urlAsset.resourceLoader.setDelegate(resourceLoader, queue: resourceLoaderQueue)
urlAsset.resourceLoader.preloadsEligibleContentKeys = true

let downloadTask = downloadSession.makeAssetDownloadTask(asset: urlAsset, assetTitle: "hls stream", assetArtworkData: nil, options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: bitrate]) 

downloadTask.resume()
