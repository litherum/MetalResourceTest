//
//  main.swift
//  MetalTest
//
//  Created by Litherum on 8/13/19.
//  Copyright © 2019 Litherum. All rights reserved.
//

import Foundation
import Metal

let shaderSource = """
#include <metal_stdlib>

using namespace metal;

struct Arguments {
    device float* b [[id(0)]];
};

kernel void computeShader(device Arguments* a [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
    a[tid].b[0] = 17;
}
"""

let device = MTLCreateSystemDefaultDevice()!

var resources = [MTLBuffer]()
let before = device.currentAllocatedSize
//let numResources = 66000
let numResources = 20000
for _ in 0 ..< numResources {
    resources.append(device.makeBuffer(length: Int(7.5 * Double(4096 * MemoryLayout<Float>.size)), options: .storageModePrivate)!)
}
let after = device.currentAllocatedSize
print("Average resource size: \(Float(after - before) / Float(resources.count)) Total: \(after - before)")

let library = try! device.makeLibrary(source: shaderSource, options: nil)
let function = library.makeFunction(name: "computeShader")!
let argumentEncoder = function.makeArgumentEncoder(bufferIndex: 0)
assert(argumentEncoder.encodedLength >= argumentEncoder.alignment)
assert(argumentEncoder.encodedLength % argumentEncoder.alignment == 0)
let argumentBuffer = device.makeBuffer(length: argumentEncoder.encodedLength * numResources, options: .storageModeShared)!
for i in 0 ..< numResources {
    argumentEncoder.setArgumentBuffer(argumentBuffer, startOffset: 0, arrayElement: i)
    argumentEncoder.setBuffer(resources[i], offset: 0, index: 0)
}

let pipelineState = try! device.makeComputePipelineState(function: function)
let queue = device.makeCommandQueue()!
let commandBuffer = queue.makeCommandBuffer()!
let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
commandEncoder.setComputePipelineState(pipelineState)
commandEncoder.setBuffer(argumentBuffer, offset: 0, index: 0)
for i in 0 ..< resources.count {
    commandEncoder.useResource(resources[i], usage: [.read, .write])
}
commandEncoder.dispatchThreadgroups(MTLSize(width: numResources, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
commandEncoder.endEncoding()
commandBuffer.addCompletedHandler {(commandBuffer) in
    DispatchQueue.main.async {
        print("Command buffer completed: \(commandBuffer.status == .completed)")
        print("Command buffer error: \(commandBuffer.status == .error) \(commandBuffer.error)")
        //print("Command buffer runtime: \(commandBuffer.GPUEndTime - commandBuffer.GPUStartTime)")
        /*let results = resources.map {(resource) -> Float in
            let pointer = resource.contents().bindMemory(to: Float.self, capacity: 1)
            return pointer[0]
        }
        for result in results {
            assert(result == 17)
        }*/
        print("Success!")
    }
}
commandBuffer.addScheduledHandler {(commandBuffer) in
    DispatchQueue.main.async {
        print("Scheduled...")
    }
}
commandBuffer.commit()
print("Waiting for results...")
RunLoop.main.run()
