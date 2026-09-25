import AVFoundation
import Foundation

private final class AudioConverterInputProvider: @unchecked Sendable {
  private let lock = NSLock()
  private let buffer: AVAudioPCMBuffer
  private var hasSuppliedBuffer = false

  init(buffer: AVAudioPCMBuffer) {
    self.buffer = buffer
  }

  func nextBuffer(
    status: UnsafeMutablePointer<AVAudioConverterInputStatus>
  ) -> AVAudioBuffer? {
    lock.lock()
    defer { lock.unlock() }
    guard !hasSuppliedBuffer else {
      status.pointee = .noDataNow
      return nil
    }
    hasSuppliedBuffer = true
    status.pointee = .haveData
    return buffer
  }
}

extension AVAudioPCMBuffer {
  func copyBuffer() -> AVAudioPCMBuffer? {
    guard frameLength > 0,
      let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)
    else {
      return nil
    }
    copy.frameLength = frameLength
    let channels = Int(format.channelCount)
    let frames = Int(frameLength)
    let isInterleaved = format.isInterleaved

    if let src = floatChannelData, let dst = copy.floatChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Float>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Float>.size)
        }
      }
      return copy
    }
    if let src = int16ChannelData, let dst = copy.int16ChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Int16>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Int16>.size)
        }
      }
      return copy
    }
    if let src = int32ChannelData, let dst = copy.int32ChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Int32>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Int32>.size)
        }
      }
      return copy
    }
    let srcBuffers = UnsafeMutableAudioBufferListPointer(self.mutableAudioBufferList)
    let dstBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
    for (src, dst) in zip(srcBuffers, dstBuffers) {
      if let srcData = src.mData, let dstData = dst.mData {
        memcpy(dstData, srcData, min(Int(src.mDataByteSize), Int(dst.mDataByteSize)))
      }
    }
    return copy
  }
}

extension AudioCaptureEngine {
  func write(_ buffer: AVAudioPCMBuffer) {
    guard buffer.frameLength > 0 else { return }

    var levelToPublish: Double?
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastLevelPublishedAt >= 0.05 {
      lastLevelPublishedAt = now
      levelToPublish = normalizedLevel(in: buffer)
    }

    if let levelToPublish {
      levelHandler?(levelToPublish)
    }

    guard isRecordingActive, let bufferCopy = buffer.copyBuffer() else { return }
    audioProcessingQueue.async { [weak self] in
      self?.processAudioBuffer(bufferCopy)
    }
  }

  func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    fileLock.lock()
    guard let activeFile else {
      fileLock.unlock()
      return
    }

    var streamingChunks: [Data] = []
    let chunkHandler = audioChunkHandler

    if writeFailure == nil {
      do {
        try activeFile.write(from: buffer)
      } catch {
        writeFailure = error
      }
    }
    if chunkHandler != nil,
      let convertedData = streamingPCMData(from: buffer)
    {
      streamingChunks = streamingChunker.append(convertedData)
    }
    // AsyncStream.yield is nonblocking. Deliver while the segment lock is
    // held so endSegment cannot close the stream before this tap's chunks.
    if let chunkHandler {
      streamingChunks.forEach(chunkHandler)
    }
    fileLock.unlock()
  }

  func configureStreamingConverter(from inputFormat: AVAudioFormat) {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
      ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    else {
      streamingOutputFormat = nil
      streamingConverter = nil
      NSLog("IOS_VALIDATION_FAILURE unable to configure 16 kHz PCM stream conversion")
      return
    }
    streamingOutputFormat = outputFormat
    streamingConverter = converter
  }

  func streamingPCMData(from inputBuffer: AVAudioPCMBuffer) -> Data? {
    guard let converter = streamingConverter,
      let outputFormat = streamingOutputFormat,
      inputBuffer.frameLength > 0
    else { return nil }

    let rateRatio = outputFormat.sampleRate / inputBuffer.format.sampleRate
    let estimatedFrames = ceil(Double(inputBuffer.frameLength) * rateRatio) + 32
    let boundedFrames = max(1, min(estimatedFrames, Double(UInt32.max)))
    guard
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: AVAudioFrameCount(boundedFrames)
      )
    else { return nil }

    let inputProvider = AudioConverterInputProvider(buffer: inputBuffer)
    var conversionError: NSError?
    let status = converter.convert(
      to: outputBuffer,
      error: &conversionError
    ) { _, inputStatus in
      inputProvider.nextBuffer(status: inputStatus)
    }

    if let conversionError {
      NSLog("LIVE_AUDIO_CONVERSION_FAILED error=%@", conversionError.localizedDescription)
      reportStreamingFailure("Microphone audio conversion failed during live streaming.")
      return nil
    }
    if status == .error {
      reportStreamingFailure("Microphone audio conversion failed during live streaming.")
      return nil
    }
    guard status == .haveData || status == .inputRanDry,
      outputBuffer.frameLength > 0
    else { return nil }

    let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
    let validBytes = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
    guard let bytes = audioBuffer.mData, validBytes > 0 else { return nil }
    return Data(bytes: bytes, count: validBytes)
  }

  func finishStreamingPCMData() -> [Data] {
    guard let converter = streamingConverter,
      let outputFormat = streamingOutputFormat
    else { return [] }

    var output: [Data] = []
    for _ in 0..<8 {
      guard
        let outputBuffer = AVAudioPCMBuffer(
          pcmFormat: outputFormat,
          frameCapacity: 4_096
        )
      else { break }

      var conversionError: NSError?
      let status = converter.convert(
        to: outputBuffer,
        error: &conversionError
      ) { _, inputStatus in
        inputStatus.pointee = .endOfStream
        return nil
      }
      if let conversionError {
        NSLog("LIVE_AUDIO_CONVERSION_FLUSH_FAILED error=%@", conversionError.localizedDescription)
        reportStreamingFailure("Microphone audio conversion could not finish the live stream.")
        break
      }
      if status == .error {
        reportStreamingFailure("Microphone audio conversion could not finish the live stream.")
        break
      }

      if outputBuffer.frameLength > 0 {
        let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
        let validBytes = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        if let bytes = audioBuffer.mData, validBytes > 0 {
          output.append(Data(bytes: bytes, count: validBytes))
        }
      }
      if status == .endOfStream || outputBuffer.frameLength == 0 { break }
    }
    return output
  }

  func reportStreamingFailure(_ message: String) {
    guard !didReportStreamingFailure else { return }
    didReportStreamingFailure = true
    audioStreamingFailureHandler?(message)
  }

  func normalizedLevel(in buffer: AVAudioPCMBuffer) -> Double {
    let frameCount = Int(buffer.frameLength)
    guard frameCount > 0 else { return 0 }

    let sumOfSquares: Double
    switch buffer.format.commonFormat {
    case .pcmFormatFloat32:
      guard let samples = buffer.floatChannelData?[0] else { return 0 }
      var sum = 0.0
      for index in 0..<frameCount {
        let sample = Double(samples[index])
        sum += sample * sample
      }
      sumOfSquares = sum
    case .pcmFormatInt32:
      guard let samples = buffer.int32ChannelData?[0] else { return 0 }
      var sum = 0.0
      for index in 0..<frameCount {
        let sample = Double(samples[index]) / Double(Int32.max)
        sum += sample * sample
      }
      sumOfSquares = sum
    case .pcmFormatInt16:
      guard let samples = buffer.int16ChannelData?[0] else { return 0 }
      var sum = 0.0
      for index in 0..<frameCount {
        let sample = Double(samples[index]) / Double(Int16.max)
        sum += sample * sample
      }
      sumOfSquares = sum
    default:
      return 0
    }

    let rootMeanSquare = sqrt(sumOfSquares / Double(frameCount))
    let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
    let linear = min(max((decibels + 48) / 42, 0), 1)
    return pow(linear, 0.70)
  }
}
