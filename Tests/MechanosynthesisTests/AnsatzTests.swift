import XCTest
import Mechanosynthesis
import Numerics

final class AnsatzTests: XCTestCase {
  static func checkFragments(
    _ waveFunction: WaveFunction,
    _ expectedCount: Int
  ) {
    print("fragment count:", waveFunction.cellValues.count)
    XCTAssertGreaterThanOrEqual(waveFunction.cellValues.count, expectedCount)
    XCTAssertLessThan(waveFunction.cellValues.count, expectedCount * 2)
  }
  
  static func queryRadius(
    waveFunction: WaveFunction,
    nucleusPosition: SIMD3<Float> = .zero
  ) -> Float {
    var sum: Double = .zero
    let octree = waveFunction.octree
    for nodeID in octree.linkedList.indices {
      if octree.linkedList[nodeID].childCount > 0 {
        continue
      }
      
      let metadata = octree.metadata[nodeID]
      var x = SIMD8<Float>(0, 1, 0, 1, 0, 1, 0, 1) * 0.5 - 0.25
      var y = SIMD8<Float>(0, 0, 1, 1, 0, 0, 1, 1) * 0.5 - 0.25
      var z = SIMD8<Float>(0, 0, 0, 0, 1, 1, 1, 1) * 0.5 - 0.25
      x = x * metadata.w + metadata.x
      y = y * metadata.w + metadata.y
      z = z * metadata.w + metadata.z
      x -= nucleusPosition.x
      y -= nucleusPosition.y
      z -= nucleusPosition.z
      
      let Ψ = waveFunction.cellValues[nodeID]
      let r = (x * x + y * y + z * z).squareRoot()
      let ΨrΨ = Ψ * r * Ψ
      
      let d3r = metadata.w * metadata.w * metadata.w
      sum += Double(ΨrΨ.sum() / 8 * d3r)
    }
    
    let output = Float(sum) * 2 / 3
    print("expectation radius:", output)
    return output
  }
  
  func testHydrogen() throws {
    print()
    print("testHydrogen")
    
    var descriptor = AnsatzDescriptor()
    descriptor.atomicNumbers = [1]
    descriptor.fragmentCount = 1000
    descriptor.positions = [.zero]
    descriptor.sizeExponent = 4
    
    // Test a proton.
    descriptor.netCharges = [+1]
    descriptor.netSpinPolarizations = [0]
    let proton = Ansatz(descriptor: descriptor)
    XCTAssertEqual(proton.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(proton.spinNeutralWaveFunctions.count, 0)
    XCTAssertEqual(proton.spinUpWaveFunctions.count, 0)
    
    // Test a neutral hydrogen atom (positive spin).
    descriptor.netCharges = [0]
    descriptor.netSpinPolarizations = [1]
    let hydrogenUp = Ansatz(descriptor: descriptor)
    XCTAssertEqual(hydrogenUp.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(hydrogenUp.spinNeutralWaveFunctions.count, 0)
    XCTAssertEqual(hydrogenUp.spinUpWaveFunctions.count, 1)
    Self.checkFragments(hydrogenUp.spinUpWaveFunctions[0], 1000)
    XCTAssertEqual(1, Self.queryRadius(
      waveFunction: hydrogenUp.spinUpWaveFunctions[0]), accuracy: 0.02)
    
    // Test a neutral hydrogen atom (negative spin).
    descriptor.netCharges = [0]
    descriptor.netSpinPolarizations = [-1]
    let hydrogenDown = Ansatz(descriptor: descriptor)
    XCTAssertEqual(hydrogenDown.spinDownWaveFunctions.count, 1)
    XCTAssertEqual(hydrogenDown.spinNeutralWaveFunctions.count, 0)
    XCTAssertEqual(hydrogenDown.spinUpWaveFunctions.count, 0)
    Self.checkFragments(hydrogenDown.spinDownWaveFunctions[0], 1000)
    XCTAssertEqual(1, Self.queryRadius(
      waveFunction: hydrogenDown.spinDownWaveFunctions[0]), accuracy: 0.02)
    
    // Test a hydride anion (singlet state).
    descriptor.netCharges = [-1]
    descriptor.netSpinPolarizations = [0]
    let hydrideSinglet = Ansatz(descriptor: descriptor)
    XCTAssertEqual(hydrideSinglet.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(hydrideSinglet.spinNeutralWaveFunctions.count, 1)
    XCTAssertEqual(hydrideSinglet.spinUpWaveFunctions.count, 0)
    Self.checkFragments(hydrideSinglet.spinNeutralWaveFunctions[0], 1000)
    XCTAssertEqual(1, Self.queryRadius(
      waveFunction: hydrideSinglet.spinNeutralWaveFunctions[0]), accuracy: 0.02)
    
    // Test a hydride anion (triplet state).
    descriptor.atomicNumbers = [1]
    descriptor.netCharges = [-1]
    descriptor.netSpinPolarizations = [2]
    let hydrideTriplet = Ansatz(descriptor: descriptor)
    XCTAssertEqual(hydrideTriplet.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(hydrideTriplet.spinNeutralWaveFunctions.count, 0)
    XCTAssertEqual(hydrideTriplet.spinUpWaveFunctions.count, 2)
    Self.checkFragments(hydrideTriplet.spinUpWaveFunctions[0], 1000)
    Self.checkFragments(hydrideTriplet.spinUpWaveFunctions[1], 1000)
    XCTAssertEqual(1, Self.queryRadius(
      waveFunction: hydrideTriplet.spinUpWaveFunctions[0]), accuracy: 0.02)
    XCTAssertEqual(2, Self.queryRadius(
      waveFunction: hydrideTriplet.spinUpWaveFunctions[1]), accuracy: 0.08)
  }
  
  func testLithium() throws {
    print()
    print("testLithium")
    
    var descriptor = AnsatzDescriptor()
    descriptor.atomicNumbers = [3]
    descriptor.fragmentCount = 1000
    descriptor.positions = [.zero]
    descriptor.sizeExponent = 4
    
    // Test an ion.
    descriptor.netCharges = [+1]
    descriptor.netSpinPolarizations = [0]
    let lithiumIon = Ansatz(descriptor: descriptor)
    XCTAssertEqual(lithiumIon.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(lithiumIon.spinNeutralWaveFunctions.count, 1)
    XCTAssertEqual(lithiumIon.spinUpWaveFunctions.count, 0)
    Self.checkFragments(lithiumIon.spinNeutralWaveFunctions[0], 1000)
    XCTAssertEqual(0.414, Self.queryRadius(
      waveFunction: lithiumIon.spinNeutralWaveFunctions[0]), accuracy: 0.02)
    
    // Test a neutral atom.
    descriptor.netCharges = [0]
    descriptor.netSpinPolarizations = [-1]
    let lithiumNeutral = Ansatz(descriptor: descriptor)
    XCTAssertEqual(lithiumNeutral.spinDownWaveFunctions.count, 1)
    XCTAssertEqual(lithiumNeutral.spinNeutralWaveFunctions.count, 1)
    XCTAssertEqual(lithiumNeutral.spinUpWaveFunctions.count, 0)
    Self.checkFragments(lithiumNeutral.spinDownWaveFunctions[0], 1000)
    Self.checkFragments(lithiumNeutral.spinNeutralWaveFunctions[0], 1000)
    XCTAssertEqual(0.414, Self.queryRadius(
      waveFunction: lithiumNeutral.spinNeutralWaveFunctions[0]), accuracy: 0.02)
    XCTAssertEqual(2, Self.queryRadius(
      waveFunction: lithiumNeutral.spinDownWaveFunctions[0]), accuracy: 0.08)
    
    // Test a spin-3/2 atom.
    descriptor.netCharges = [0]
    descriptor.netSpinPolarizations = [3]
    let lithiumPolarized = Ansatz(descriptor: descriptor)
    XCTAssertEqual(lithiumPolarized.spinDownWaveFunctions.count, 0)
    XCTAssertEqual(lithiumPolarized.spinNeutralWaveFunctions.count, 0)
    XCTAssertEqual(lithiumPolarized.spinUpWaveFunctions.count, 3)
    Self.checkFragments(lithiumPolarized.spinUpWaveFunctions[0], 1000)
    Self.checkFragments(lithiumPolarized.spinUpWaveFunctions[1], 1000)
    Self.checkFragments(lithiumPolarized.spinUpWaveFunctions[2], 1000)
    XCTAssertEqual(0.333, Self.queryRadius(
      waveFunction: lithiumPolarized.spinUpWaveFunctions[0]), accuracy: 0.02)
    XCTAssertEqual(1.414, Self.queryRadius(
      waveFunction: lithiumPolarized.spinUpWaveFunctions[1]), accuracy: 0.03)
    XCTAssertEqual(1.414 * 5 / 6, Self.queryRadius(
      waveFunction: lithiumPolarized.spinUpWaveFunctions[2]), accuracy: 0.03)
  }
}