//
//  ContentView.swift
//  wavsamplerate
//
//  Created by Sergey Gonchar on 07/08/2024.
//

import SwiftUI
import Accelerate
import AVFoundation

let FRAME_CAP: AVAudioFrameCount = 4096 //from apple samples, can be adjusted

protocol SourceBuffer {
    var buffer: AVAudioPCMBuffer { get }
    var processingFormat: AVAudioFormat { get }
    func refill(for count: AVAudioPacketCount) -> AVAudioConverterInputStatus
}

class Converter {
    let source: SourceBuffer
    let converter: AVAudioConverter
    let outputBuffer: AVAudioPCMBuffer
    init(
        source: SourceBuffer,
        format: AVAudioFormat
    ) {
        self.source = source
        self.converter =  AVAudioConverter(from: source.processingFormat, to: format)!
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        converter.sampleRateConverterQuality = .max
        self.outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: FRAME_CAP)!
        print("new converter: \n - from: \(source.processingFormat) \n - to: \(format)" )
    }
    
    func step() -> AVAudioConverterOutputStatus {
        return self.converter.convert(to: self.outputBuffer, error: nil) { (numberOfPackets, outStatus) -> AVAudioBuffer? in
            let status = self.source.refill(for: numberOfPackets)
            if status == .haveData {
                outStatus.pointee = .haveData
                return self.source.buffer
            }
            outStatus.pointee = .endOfStream
            return nil
        }
    }
}

class FileSourceBuffer: SourceBuffer {
    let inputFile: AVAudioFile
    let buffer: AVAudioPCMBuffer
    
    init(inputFile: AVAudioFile) {
        self.inputFile = inputFile
        self.buffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: FRAME_CAP)!
    }
    
    var processingFormat: AVAudioFormat {
        return inputFile.processingFormat
    }
    
    func refill(for numberOfFrames: AVAudioPacketCount) -> AVAudioConverterInputStatus {
        do {
            try inputFile.read(into: buffer)
            return buffer.frameLength > 0 ? .haveData : .endOfStream
        } catch {
            return .endOfStream
        }
    }
}


class CopySourceBuffer: SourceBuffer {
    let input: SourceBuffer
    let buffer: AVAudioPCMBuffer
    
    init(input: SourceBuffer) {
        self.input = input
        self.buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: FRAME_CAP)!
    }
    
    var processingFormat: AVAudioFormat {
        return input.processingFormat
    }
    
    func refill(for numberOfFrames: AVAudioPacketCount) -> AVAudioConverterInputStatus {
        let status = input.refill(for: numberOfFrames)
        
        if (status == .endOfStream) {
            return .endOfStream
        }

        guard let inputChannelData = input.buffer.floatChannelData,
              let bufferChannelData = buffer.floatChannelData else {
            print("Failed to access channel data")
            return .endOfStream
        }

        buffer.frameLength = input.buffer.frameLength

        let numChannels = Int(buffer.format.channelCount)
        let numFrames = Int(input.buffer.frameLength)
        
        for channel in 0..<numChannels {
            memmove(bufferChannelData[channel], inputChannelData[channel], numFrames * MemoryLayout<Float>.size)
        }
        
        return status
    }
}

class ConverterSourceBuffer: SourceBuffer {
    let input: Converter
    
    init(
        input: Converter
    ) {
        self.input = input
    }

    var buffer: AVAudioPCMBuffer {
        return input.outputBuffer
    }
    
    var processingFormat: AVAudioFormat {
        return self.input.converter.outputFormat
    }
    
    func refill(for numberOfFrames: AVAudioPacketCount) -> AVAudioConverterInputStatus {
        let status = self.input.step()
        return status == .haveData ? .haveData : .endOfStream
    }
}


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
  
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let bufferSize: AVAudioFrameCount = 4096
    let outputFormat_2_48 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: true)!
    let outputFormat_1_16 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    
  func loadAndProcessWAVFromURL(_ url: URL) throws -> [Float]? {
      
      let inputFile = try AVAudioFile(forReading: url)
      
      // Array to hold the converted audio samples
      var outputSamples = [Float]()

      let file = FileSourceBuffer(inputFile: inputFile)
      let conv1 = Converter(source: file, format: outputFormat_2_48)
      //conv1.converter.downmix = true // do not work for 5 channels
      conv1.converter.channelMap = [0,1] // will get first 2 channel from 5

      let convsrc = ConverterSourceBuffer(input: conv1)
      //let copy = CopySourceBuffer(input: convsrc)
      let conv2 = Converter(source: convsrc, format: outputFormat_1_16)
      conv2.converter.downmix = true // now we can mix 2 channel to 1 channel

      
      let conv = conv2
      
      let outputFile = try AVAudioFile(
        forWriting: documents.appendingPathComponent("output.wav"),
        settings: conv.outputBuffer.format.settings,
        commonFormat: conv.outputBuffer.format.commonFormat,
        interleaved: conv.outputBuffer.format.isInterleaved
      )
      
      while true {
          
          let status = conv.step()

          if status == .haveData {
              let outputData = Array(
                UnsafeBufferPointer(
                    start: conv.outputBuffer.floatChannelData!.pointee,
                    count: Int(conv.outputBuffer.frameLength)
                )
              )
              outputSamples.append(contentsOf: outputData)
              try outputFile.write(from: conv.outputBuffer)
          } else {
              break
          }
      }
      
      return outputSamples

  }
  
  func load() {
    guard let audioFileURL = Bundle.main.url(forResource: "audio", withExtension: "wav") else {
      return
    }
      
    do {
        if let result = try loadAndProcessWAVFromURL(audioFileURL) {
            print("Conversion successful, number of samples: \(result.count)")
            print(result[0])
            print(result[10])
            print(result[11])
            print(result[120])
            print("here")
        }
    } catch {
        print("Error during conversion: \(error.localizedDescription)")
    }
    
  }
  
  init() {
    load()
  }
  
}
