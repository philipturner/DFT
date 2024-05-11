import XCTest
import Mechanosynthesis
import Numerics

final class LinearSolverTests: XCTestCase {
  // Creates a 1D Laplacian operator with 2nd order accuracy.
  #if false
  // NOTE: Coded prematurely, just here as reference.
  static func laplacian(h: Float) -> ([Float]) -> [Float] {
    return { potential in
      var chargeDensity: [Float] = []
      
      for cellID in potential.indices {
        var left: Float = .zero
        var center: Float = .zero
        var right: Float = .zero
        
        if potential.indices.contains(cellID - 1) {
          left = potential[cellID - 1]
        }
        if potential.indices.contains(cellID) {
          center = potential[cellID]
        }
        if potential.indices.contains(cellID + 1) {
          right = potential[cellID + 1]
        }
        
        let leftDerivative = (center - left) / h
        let rightDerivative = (right - center) / h
        let doubleDerivative = (rightDerivative - leftDerivative) / h
        chargeDensity.append(doubleDerivative)
      }
      return chargeDensity
    }
  }
  #endif
  
  // Test the process of setting up a simulation domain.
  func testDirectIntegration() throws {
    // The nucleus appears in the center of the grid. Its charge is +1.
    let h: Float = 0.1
    let gridSize: Int = 10
    
    // Create an array that represents the charge density (ρ).
    var chargeGrid = [Float](repeating: .zero, count: gridSize * gridSize)
    guard gridSize % 2 == 0 else {
      fatalError("The number of cells must be even.")
    }
    
    // Divide the charge among four cells in the center.
    do {
      let totalCharge = Float(1)
      let chargePerCell = totalCharge / 4
      let chargeDensity = chargePerCell / (h * h)
      
      var cellIndices: [Int] = []
      let size = gridSize
      cellIndices.append((size / 2 - 1) * size + (size / 2 - 1))
      cellIndices.append((size / 2 - 1) * size + (size / 2))
      cellIndices.append((size / 2) * size + (size / 2 - 1))
      cellIndices.append((size / 2) * size + (size / 2))
      
      for cellID in cellIndices {
        chargeGrid[cellID] = chargeDensity
      }
    }
    
    // Visualize the contents of the charge grid.
    print()
    print("charge density")
    for indexY in 0..<gridSize {
      for indexX in 0..<gridSize {
        let x = (Float(indexX) + 0.5) * h
        let y = (Float(indexY) + 0.5) * h
        let cellID = indexY * gridSize + indexX
        
        let ρ = chargeGrid[cellID]
        print(ρ, terminator: " ")
      }
      print()
    }
    
    // Create an array that represents the boundary values in each cell.
    // - With the modeled point-charge potential.
    // - With the result of integration.
    //
    // Do either of the results satisfy the divergence theorem? If not, what
    // is the easiest way to restore charge conservation?
    
    // Elements of the flux data structure:
    // - [0] = lower X face
    // - [1] = lower Y face
    // - [2] = upper X face
    // - [3] = upper Y face
    var fluxPointCharge = [SIMD4<Float>](
      repeating: .zero, count: gridSize * gridSize)
    for indexY in 0..<gridSize {
      for indexX in 0..<gridSize {
        // Create the coordinate offsets for each face.
        let faceOffsetsX: [Float] = [-0.5, 0.0, 0.5, 0.0]
        let faceOffsetsY: [Float] = [0.0, -0.5, 0.0, 0.5]
        var faceCenters: [SIMD2<Float>] = []
        for faceID in 0..<4 {
          var x = (Float(indexX) + 0.5) * h
          var y = (Float(indexY) + 0.5) * h
          x += faceOffsetsX[faceID] * h
          y += faceOffsetsY[faceID] * h
          
          // Group the X and Y coordinates into a vector.
          let center = SIMD2(x, y)
          faceCenters.append(center)
        }
        
        if Float.random(in: 0..<1) < 0.1 {
          print(indexX, indexY, faceCenters)
        }
      }
    }
    
#if false
    // Visualize the fluxes along the boundaries.
    do {
      print()
      print("boundary (X)")
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          let x = (Float(indexX) + 0.5) * h
          let y = (Float(indexY) + 0.5) * h
          let cellID = indexY * gridSize + indexX
          
          let F = boundaryGridX[cellID]
          print(F, terminator: " ")
        }
        print()
      }
      
      print()
      print("boundary (Y)")
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          let x = (Float(indexX) + 0.5) * h
          let y = (Float(indexY) + 0.5) * h
          let cellID = indexY * gridSize + indexX
          
          let F = boundaryGridY[cellID]
          print(F, terminator: " ")
        }
        print()
      }
    }
#endif
  }
  
  // Implementation of the algorithm from the INQ codebase, which chooses the
  // timestep based on the results of some integrals.
  func testSteepestDescent() throws {
    
  }
  
  // Implementation of weighted Jacobi, using a fixed timestep determined by
  // the grid spacing.
  func testWeightedJacobi() throws {
    
  }
  
  // Implementation of Gauss-Seidel, using a fixed timestep determined by the
  // grid spacing.
  //
  // This test does not cover the Gauss-Seidel red-black ordering scheme.
  // However, the results should reveal how one would go about coding GSRB.
  func testGaussSeidel() throws {
    
  }
  
  // Implementation of the algorithm from the INQ codebase, which chooses the
  // timestep based on the results of some integrals.
  func testConjugateGradient() throws {
    
  }
}
