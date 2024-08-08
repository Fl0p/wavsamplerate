//
//  ContentView.swift
//  wavsamplerate
//
//  Created by Sergey Gonchar on 07/08/2024.
//

import SwiftUI
import Accelerate
import AVFoundation

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
    }
    .padding()
  }
  
  
  func loadAndProcessWAVFromURL(_ url: URL) -> [Float]? {
    do {
      // Load the audio file
      let audioFile = try AVAudioFile(forReading: url)
      
      // Get the audio format
      let audioFormat = audioFile.processingFormat
      let sampleRate = audioFormat.sampleRate
      let channelCount = audioFormat.channelCount
      
      // Read the audio data
      let audioFrameCount = UInt32(audioFile.length)
      let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)!
      try audioFile.read(into: audioBuffer)
      
      print(audioBuffer.floatChannelData?.pointee.pointee ?? "float no")
      print(audioBuffer.int16ChannelData?.pointee.pointee ?? "int16 no")
      print(audioBuffer.int32ChannelData?.pointee.pointee ?? "int32 no")
      
      
      // Resample to 16000 Hz
      let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: true)!
      let converter = AVAudioConverter(from: audioFormat, to: targetFormat)!
      converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
      converter.sampleRateConverterQuality = .max
//      converter.downmix = true
//      converter.bitRate = 32 * 16000
//
      
      let ratio = targetFormat.sampleRate / sampleRate
      let outputFrameCount = AVAudioFrameCount(Double(audioFrameCount) * ratio)
      let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount)!
      
      var error: NSError?
      let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
        outStatus.pointee = AVAudioConverterInputStatus.haveData
        // here we read by packets but ok lets consider we have the same buffer over and over again
        return audioBuffer
      }
      
      converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
      
      //this line doesnt work because
      //*** Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio', reason: 'required condition is false: outputBuffer.frameCapacity >= inputBuffer.frameLength'
      
//      we can't use this because documentation states Performs a basic conversion between audio formats that doesn’t involve converting codecs or sample rates.
//      try! converter.convert(to: outputBuffer, from: audioBuffer)
      
      print(outputBuffer.floatChannelData?.pointee.pointee ?? "float no")
      print(outputBuffer.int16ChannelData?.pointee.pointee ?? "int16 no")
      print(outputBuffer.int32ChannelData?.pointee.pointee ?? "int32 no")
      
      // PROBLEM IS THAT DATA HERE IS ALL ZEROS AFTER CONVERSION
      let resampledData = Array(UnsafeBufferPointer(start: outputBuffer.floatChannelData?[0], count: Int(outputBuffer.frameLength)))
      
      return resampledData
    } catch {
      print("Error loading WAV file: \(error)")
      return nil
    }
  }
  
  func load() {
    guard let audioFileURL = Bundle.main.url(forResource: "audio", withExtension: "wav") else {
      return
    }
    if let result = loadAndProcessWAVFromURL(audioFileURL) {
      print(result[0])
      print(result[10])
      print(result[11])
      print(result[12])
      print("here")
    }
    
  }
  
  init() {
    load()
  }
  
}
