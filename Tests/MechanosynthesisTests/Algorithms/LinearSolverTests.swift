import XCTest
import Mechanosynthesis
import Numerics

// Performance of different algorithms
//
// ========================================================================== //
// Methods
// ========================================================================== //
//
// Specification of multigrid V-cycle
//   A-B-C-D-E
//
//   A GSRB (1x)
//   -> B GSRB (2x)
//   ---> C GSRB (4x)
//   -> D GSRB (2x)
//   E GSRB (1x)
//   update solution
//
//   One V-cycle counts as one iteration. It is effectively the compute cost
//   of two Gauss-Seidel iterations.
//
// ========================================================================== //
// Results
// ========================================================================== //
//
// h = 0.25, gridSize = 8, cellCount = 512
//                       0 iters  ||r|| = 394.27557
// Gauss-Seidel         30 iters  ||r|| = 6.5650797      0.002 seconds
// Conjugate Gradient   30 iters  ||r|| = 0.00030688613  0.003 seconds
// Preconditioned CG    15 iters  ||r|| = 0.00023875975  0.003 seconds
// Multigrid 1-1-1-1-1  15 iters  ||r|| = 0.017259505    0.004 seconds
// Multigrid 1-2-1-2-1  10 iters  ||r|| = 0.00020144212  0.003 seconds
// Multigrid 1-4-1       7 iters  ||r|| = 0.00019803157  0.003 seconds
//
// h = 0.125, gridSize = 16, cellCount = 4096
//                       0 iters  ||r|| = 3091.9424
// Gauss-Seidel         30 iters  ||r|| = 277.43747     0.016 seconds
// Conjugate Gradient   30 iters  ||r|| = 0.09551496    0.017 seconds
// Preconditioned CG    15 iters  ||r|| = 0.0032440922  0.024 seconds
// Multigrid 1-1-1-1-1  15 iters  ||r|| = 0.0023769636  0.025 seconds
// Multigrid 1-2-1-2-1  12 iters  ||r|| = 0.0025058207  0.024 seconds
// Multigrid 1-2-2-2-1  10 iters  ||r|| = 0.0023211893  0.021 seconds
// Multigrid 1-2-4-2-1  12 iters  ||r|| = 0.0025251452  0.025 seconds
//
// h = 0.0625, gridSize = 32, cellCount = 32,768
//                           0 iters  ||r|| = 24494.229
// Gauss-Seidel             60 iters  ||r|| = 1308.8044    0.250 seconds
// Conjugate Gradient       60 iters  ||r|| = 0.49065304   0.258 seconds
// Preconditioned CG        30 iters  ||r|| = 0.048568394  0.364 seconds
// Multigrid 1-1-1-1-1-1-1  30 iters  ||r|| = 0.029823668  0.408 seconds
// Multigrid 1-2-2-1-2-2-1  15 iters  ||r|| = 0.02897086   0.242 seconds
// Multigrid 1-2-4-2-1      15 iters  ||r|| = 0.028649306  0.251 seconds
//
// h = 0.0313, gridSize = 64, cellCount = 262,144
//                           0 iters  ||r|| = 195015.61
// Gauss-Seidel             99 iters  ||r|| = 5887.104    3.311 seconds
// Conjugate Gradient       99 iters  ||r|| = 53.441914   3.375 seconds
// Preconditioned CG        50 iters  ||r|| = 0.72252524  4.823 seconds
// Multigrid 1-1-1-1-1-1-1  35 iters  ||r|| = 0.45097157  3.831 seconds
// Multigrid 1-2-2-1-2-2-1  30 iters  ||r|| = 0.3642269   3.951 seconds
// Multigrid 1-2-2-2-2-2-1  20 iters  ||r|| = 0.36008823  2.601 seconds
// Multigrid 1-2-2-4-2-2-1  20 iters  ||r|| = 0.30006418  2.613 seconds
//
// h = 0.0156, gridSize = 128, cellCount = 2,097,152
//                               0 iters  ||r|| = 1556438.4
// Preconditioned CG            60 iters  ||r|| = 1209.9086  46.300 seconds
// Preconditioned CG            99 iters  ||r|| = 11.659912  75.554 seconds
// Multigrid 1-1-1-1-1-1-1      60 iters  ||r|| = 225.7327   52.499 seconds
// Multigrid 1-1-1-2-1-1-1      60 iters  ||r|| = 25.65553   52.680 seconds
// Multigrid 1-2-2-2-2-2-1      60 iters  ||r|| = 6.335201   62.544 seconds
// Multigrid 1-2-2-4-2-2-1      40 iters  ||r|| = 3.906945   42.194 seconds
// Multigrid 1-2-2-2-1-2-2-2-1  28 iters  ||r|| = 3.576714   29.415 seconds
//
// Consistent pattern for reliably-performing grids:
// Multigrid 1-4-1           7 iters  ||r|| = 0.00019803157  0.003 seconds
// Multigrid 1-2-4-2-1      12 iters  ||r|| = 0.0025251452   0.025 seconds
// Multigrid 1-2-4-2-1      15 iters  ||r|| = 0.028649306    0.251 seconds
// Multigrid 1-2-2-4-2-2-1  20 iters  ||r|| = 0.30006418     2.613 seconds
// Multigrid 1-2-2-4-2-2-1  40 iters  ||r|| = 3.906945      42.194 seconds
//
// ========================================================================== //
// Discussion
// ========================================================================== //
//
// NOTE: These notes were made when there was a major bug in the multigrid
// implementation. Now, multigrid performs much better. It is consistently
// faster than conjugate gradient.
//
// Ranked by ease of implementation:
// 1) Jacobi
// 2) Gauss-Seidel
// 3) Conjugate gradient
// 4) Preconditioned conjugate gradient
// 5) Multigrid
//
// Preconditioned CG seems like the best tradeoff between complexity and speed.
// It converges consistently in every situation. Multigrid requires careful
// tuning of the tree depth and often fails to converge with the wrong V-cycle
// scheme. However, it has the potential to be more efficient, especially with
// BMR FAS-FMG.
//
// I'm also unsure how adaptive mesh refinement will affect the performance of
// these algorithms. The path length to jump between levels would increase
// significantly. Multigrid would coalesce the overhead of interpolation
// and coarsening operations. However, the CG preconditioner could be modified
// with higher / anisotropic sample count at the nuclear singularity.
//
// ========================================================================== //
// Conclusion
// ========================================================================== //
//
// Final conclusion: support both the 33-point PCG and multigrid solvers in
// this library. PCG is definitely more robust and requires less fine tuning.
// However, multigrid outperforms it for large systems. There might be an API
// for the user to fine-tune the multigrid scheme.
//
// This is similar to MM4, which supports two integrators:
// - .verlet (more efficient for small systems; default)
// - .multipleTimeStep (more efficient for large systems)
//
// Mechanosynthesis would have two solvers:
// - .conjugateGradient (more robust; default)
// - .multigrid (more efficient)
final class LinearSolverTests: XCTestCase {
  static let gridSize: Int = 8
  static let h: Float = 0.25
  static var cellCount: Int { gridSize * gridSize * gridSize }
  
  // MARK: - Utilities
  
  // Create the 'b' vector, which equals -4πρ.
  static func createScaledChargeDensity() -> [Float] {
    var output = [Float](repeating: .zero, count: cellCount)
    for permutationZ in -1...0 {
      for permutationY in -1...0 {
        for permutationX in -1...0 {
          var indices = SIMD3(repeating: gridSize / 2)
          indices[0] += permutationX
          indices[1] += permutationY
          indices[2] += permutationZ
          
          // Place 1/8 of the charge density in each of the 8 cells.
          let chargeEnclosed: Float = 1.0 / 8
          let chargeDensity = chargeEnclosed / (h * h * h)
          
          // Multiply -4π with ρ, resulting in -4πρ.
          let rhsValue = (-4 * Float.pi) * chargeDensity
          
          // Write the right-hand side to memory.
          var cellID = indices.z * (gridSize * gridSize)
          cellID += indices.y * gridSize + indices.x
          output[cellID] = rhsValue
        }
      }
    }
    return output
  }
  
  static func createAddress(indices: SIMD3<Int>) -> Int {
    indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
  }
  
  // Apply the 'A' matrix (∇^2), while omitting ghost cells.
  //
  // The Laplacian has second-order accuracy.
  static func applyLaplacianLinearPart(_ x: [Float]) -> [Float] {
    guard x.count == cellCount else {
      fatalError("Dimensions of 'x' did not match problem size.")
    }
    
    // Iterate over the cells.
    var output = [Float](repeating: 0, count: cellCount)
    for indexZ in 0..<gridSize {
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          var dotProduct: Float = .zero
          
          // Apply the FMA on the diagonal.
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = createAddress(indices: cellIndices)
          let cellValue = x[cellAddress]
          dotProduct += -6 / (h * h) * cellValue
          
          // Iterate over the faces.
          for faceID in 0..<6 {
            let coordinateID = faceID / 2
            let coordinateShift = (faceID % 2 == 0) ? -1 : 1
            
            // Locate the neighboring cell.
            var neighborIndices = SIMD3(indexX, indexY, indexZ)
            neighborIndices[coordinateID] += coordinateShift
            
            if all(neighborIndices .>= 0) && all(neighborIndices .< gridSize) {
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = x[neighborAddress]
              dotProduct += 1 / (h * h) * neighborValue
            }
          }
          
          // Store the dot product.
          output[cellAddress] = dotProduct
        }
      }
    }
    
    return output
  }
  
  // The Laplacian, omitting contributions from the input 'x'.
  //
  // Fills ghost cells with the multipole expansion of the charge enclosed.
  static func applyLaplacianBoundary() -> [Float] {
    // Iterate over the cells.
    var output = [Float](repeating: 0, count: cellCount)
    for indexZ in 0..<gridSize {
      for indexY in 0..<gridSize {
        for indexX in 0..<gridSize {
          var dotProduct: Float = .zero
          
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = createAddress(indices: cellIndices)
          
          // Iterate over the faces.
          for faceID in 0..<6 {
            let coordinateID = faceID / 2
            let coordinateShift = (faceID % 2 == 0) ? -1 : 1
            
            // Locate the neighboring cell.
            var neighborIndices = SIMD3(indexX, indexY, indexZ)
            neighborIndices[coordinateID] += coordinateShift
            
            if all(neighborIndices .>= 0) && all(neighborIndices .< gridSize) {
              
            } else {
              var neighborPosition = SIMD3<Float>(neighborIndices)
              neighborPosition = h * (neighborPosition + 0.5)
              var nucleusPosition = SIMD3(repeating: Float(gridSize))
              nucleusPosition = h * (nucleusPosition * 0.5)
              
              // Generate a ghost value from the point charge approximation.
              let r = neighborPosition - nucleusPosition
              let distance = (r * r).sum().squareRoot()
              let neighborValue = 1 / distance
              dotProduct += 1 / (h * h) * neighborValue
            }
          }
          
          // Store the dot product.
          output[cellAddress] = dotProduct
        }
      }
    }
    
    return output
  }
  
  // Create the analytical value for the solution.
  static func createReferenceSolution() -> [Float] {
    var output = [Float](repeating: .zero, count: Self.cellCount)
    for indexZ in 0..<Self.gridSize {
      for indexY in 0..<Self.gridSize {
        for indexX in 0..<Self.gridSize {
          let cellIndices = SIMD3(indexX, indexY, indexZ)
          let cellAddress = Self.createAddress(indices: cellIndices)
          
          var cellPosition = SIMD3<Float>(cellIndices)
          cellPosition = Self.h * (cellPosition + 0.5)
          var nucleusPosition = SIMD3(repeating: Float(Self.gridSize))
          nucleusPosition = Self.h * (nucleusPosition * 0.5)
          
          // Generate a ghost value from the point charge approximation.
          let r = cellPosition - nucleusPosition
          let distance = (r * r).sum().squareRoot()
          let cellValue = 1 / distance
          
          // Store the dot product.
          output[cellAddress] = cellValue
        }
      }
    }
    return output
  }
  
  // Returns the 2-norm of the residual vector.
  static func createResidualNorm(solution: [Float]) -> Float {
    guard solution.count == Self.cellCount else {
      fatalError("Solution had incorrect size.")
    }
    
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    let L1x = Self.applyLaplacianLinearPart(solution)
    let r = Self.shift(b, scale: -1, correction: L1x)
    let r2 = Self.dot(r, r)
    
    return r2.squareRoot()
  }
  
  // Shift a vector by a constant times another vector.
  //
  // Returns: original + scale * correction
  static func shift(
    _ original: [Float],
    scale: Float,
    correction: [Float]
  ) -> [Float] {
    var output = [Float](repeating: .zero, count: Self.cellCount)
    for cellID in 0..<Self.cellCount {
      var cellValue = original[cellID]
      cellValue += scale * correction[cellID]
      output[cellID] = cellValue
    }
    return output
  }
  
  // Take the dot product of two vectors.
  static func dot(
    _ lhs: [Float],
    _ rhs: [Float]
  ) -> Float {
    var accumulator: Double = .zero
    for cellID in 0..<Self.cellCount {
      let lhsValue = lhs[cellID]
      let rhsValue = rhs[cellID]
      accumulator += Double(lhsValue * rhsValue)
    }
    return Float(accumulator)
  }
  
  // MARK: - Tests
  
  // Jacobi method:
  //
  // Ax = b
  // (D + L + U)x = b
  // Dx = b - (L + U)x
  // Dx = b - (A - D)x
  // Dx = b - Ax + Dx
  // x = x + D^{-1} (b - Ax)
  func testJacobiMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Check the residual norm at the start of iterations.
    do {
      let residualNorm = Self.createResidualNorm(solution: x)
      XCTAssertEqual(residualNorm, 394, accuracy: 1)
    }
    
    // Execute the iterations.
    for _ in 0..<20 {
      let L1x = Self.applyLaplacianLinearPart(x)
      let r = Self.shift(b, scale: -1, correction: L1x)
      
      let D = -6 / (Self.h * Self.h)
      x = Self.shift(x, scale: 1 / D, correction: r)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 50)
  }
  
  // Gauss-Seidel method:
  //
  // x_i = (1 / a_ii) (b_i - Σ_(j ≠ i) a_ij x_j)
  //
  // Red-black scheme:
  //
  // iterate over all the red cells in parallel
  // iterate over all the black cells in parallel
  // only works with 2nd order FD
  //
  // a four-color scheme would work with Mehrstellen, provided we process the
  // multigrid one level at a time
  func testGaussSeidelMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Execute the iterations.
    for _ in 0..<20 {
      executeSweep(red: true, black: false)
      executeSweep(red: false, black: true)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 25)
    
    // Updates all of the selected cells in-place.
    //
    // NOTE: This function references the variables 'x' and 'b', declared in
    // the outer scope.
    func executeSweep(red: Bool, black: Bool) {
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            var dotProduct: Float = .zero
            
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            switch parity & 1 {
            case 0:
              guard red else {
                continue
              }
            case 1:
              guard black else {
                continue
              }
            default:
              fatalError("This should never happen.")
            }
            
            // Iterate over the faces.
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              
              if all(neighborIndices .>= 0),
                 all(neighborIndices .< Self.gridSize) {
                let neighborAddress = Self
                  .createAddress(indices: neighborIndices)
                let neighborValue = x[neighborAddress]
                dotProduct += 1 / (Self.h * Self.h) * neighborValue
              }
            }
            
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            
            // Overwrite the current value.
            let rhsValue = b[cellAddress]
            let diagonalValue: Float = -6 / (Self.h * Self.h)
            let newValue = (rhsValue - dotProduct) / diagonalValue
            x[cellAddress] = newValue
          }
        }
      }
    }
  }
  
  // Conjugate gradient method:
  //
  // r = b - Ax
  // p = r - Σ_i < p_i | A | r > / < p_i | A | p_i >
  // a = < p | r > / < p | A | p >
  // x = x + a p
  //
  // Efficient version:
  //
  // r = b - Ax
  // p = r
  // repeat
  //   a = < r | r > / < p | A | p >
  //   x_new = x + a p
  //   r_new = r - a A p
  //
  //   b = < r_new | r_new > / < r | r >
  //   p_new = r_new + b p
  func testConjugateGradientMethod() throws {
    // Prepare the right-hand side.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    // Prepare the solution vector.
    var x = [Float](repeating: .zero, count: Self.cellCount)
    let L1x = Self.applyLaplacianLinearPart(x)
    var r = Self.shift(b, scale: -1, correction: L1x)
    var p = r
    var rr = Self.dot(r, r)
    
    // Execute the iterations.
    for _ in 0..<20 {
      let Ap = Self.applyLaplacianLinearPart(p)
      
      let a = rr / Self.dot(p, Ap)
      let xNew = Self.shift(x, scale: a, correction: p)
      let rNew = Self.shift(r, scale: -a, correction: Ap)
      let rrNew = Self.dot(rNew, rNew)
      
      let b = rrNew / rr
      let pNew = Self.shift(rNew, scale: b, correction: p)
      
      x = xNew
      r = rNew
      p = pNew
      rr = rrNew
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
  }
  
  // Preconditioned conjugate gradient method:
  //
  // r = b - Ax
  // p = K r
  // repeat
  //   a = < r | K | r > / < p | A | p >
  //   x_new = x + a p
  //   r_new = r - a A p
  //
  //   b = < r_new | K | r_new > / < r | K | r >
  //   p_new = K r_new + b p
  func testPreconditionedConjugateGradient() throws {
    // Prepare the right-hand side.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    
    // Prepare the solution vector.
    var x = [Float](repeating: .zero, count: Self.cellCount)
    let L1x = Self.applyLaplacianLinearPart(x)
    var r = Self.shift(b, scale: -1, correction: L1x)
    var Kr = applyLaplacianPreconditioner(r)
    var rKr = Self.dot(r, Kr)
    var p = Kr
    
    // Execute the iterations.
    for _ in 0..<10 {
      let Ap = Self.applyLaplacianLinearPart(p)
      
      let a = rKr / Self.dot(p, Ap)
      let xNew = Self.shift(x, scale: a, correction: p)
      let rNew = Self.shift(r, scale: -a, correction: Ap)
      let KrNew = applyLaplacianPreconditioner(rNew)
      let rKrNew = Self.dot(rNew, KrNew)
      
      let b = rKrNew / rKr
      let pNew = Self.shift(KrNew, scale: b, correction: p)
      
      x = xNew
      r = rNew
      Kr = KrNew
      rKr = rKrNew
      p = pNew
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
    
    // Applies the 33-point convolution preconditioner.
    func applyLaplacianPreconditioner(_ x: [Float]) -> [Float] {
      let gridSize = Self.gridSize
      let cellCount = Self.cellCount
      
      @_transparent
      func createAddress(indices: SIMD3<Int16>) -> Int {
        Int(indices.z) * (gridSize * gridSize) +
        Int(indices.y) * gridSize +
        Int(indices.x)
      }
      
      // Pre-compile a list of neighbor offsets.
      var neighborData: [SIMD4<Int16>] = []
      for offsetZ in -2...2 {
        for offsetY in -2...2 {
          for offsetX in -2...2 {
            let indices = SIMD3(Int16(offsetX), Int16(offsetY), Int16(offsetZ))
            let integerDistanceSquared = (indices &* indices).wrappedSum()
            
            // This tolerance creates a 33-point convolution kernel.
            guard integerDistanceSquared <= 4 else {
              continue
            }
            
            // Execute the formula for matrix elements.
            var K: Float = .zero
            K += 0.6 * Float.exp(-2.25 * Float(integerDistanceSquared))
            K += 0.4 * Float.exp(-0.72 * Float(integerDistanceSquared))
            let quantized = Int16(K * 32767)
            
            // Pack the data into a compact 64-bit word.
            let vector = SIMD4(indices, quantized)
            neighborData.append(vector)
          }
        }
      }
      
      // Iterate over the cells.
      var output = [Float](repeating: 0, count: cellCount)
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Iterate over the convolution points.
            var accumulator: Float = .zero
            
            // The test took 0.015 seconds before.
            // 0.013 seconds
            let cellIndices64 = SIMD3(indexX, indexY, indexZ)
            let cellIndices = SIMD3<Int16>(truncatingIfNeeded: cellIndices64)
            for vector in neighborData {
              let offset = unsafeBitCast(vector, to: SIMD3<Int16>.self)
              let neighborIndices = cellIndices &+ offset
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< Int16(gridSize)) else {
                continue
              }
              
              // Read the neighbor data point from memory.
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = x[neighborAddress]
              let K = Float(vector[3]) / 32767
              accumulator += neighborValue * K
            }
            
            // Write the convolution result to memory.
            let cellAddress = createAddress(indices: cellIndices)
            output[cellAddress] = accumulator
          }
        }
      }
      
      return output
    }
  }
  
  func testMultigridMethod() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Execute the iterations.
    for _ in 0..<15 {
      // Initialize the residual.
      let L1x = Self.applyLaplacianLinearPart(x)
      let rFine = Self.shift(b, scale: -1, correction: L1x)
      
      // Smoothing iterations on the first level.
      var eFine = gaussSeidelSolve(
        r: rFine,
        coarseness: 1)
      eFine = multigridCoarseLevel(
        e: eFine, 
        r: rFine,
        fineLevelCoarseness: 1,
        fineLevelIterations: 1)
      
      // Update the solution.
      x = Self.shift(x, scale: 1, correction: eFine)
    }
    
    // Check the residual norm at the end of iterations.
    let residualNorm = Self.createResidualNorm(solution: x)
    XCTAssertLessThan(residualNorm, 0.001)
    
    // A recursive function call within the multigrid V-cycle.
    func multigridCoarseLevel(
      e: [Float], r: [Float], fineLevelCoarseness: Int, fineLevelIterations: Int
    ) -> [Float] {
      var eFine = e
      var rFine = r
      
      // Restrict from fine to coarse.
      let rFineCorrected = correctResidual(
        e: eFine,
        r: rFine,
        coarseness: fineLevelCoarseness)
      let rCoarse = shiftResolution(
        fineGrid: rFineCorrected,
        coarseGrid: [],
        fineLevelCoarseness: fineLevelCoarseness,
        shiftingUp: true)
      
      // Smoothing iterations on the coarse level.
      let coarseLevelCoarseness = 2 * fineLevelCoarseness
      var coarseLevelIterations: Int
      if coarseLevelCoarseness == 1 {
        fatalError("This should never happen.")
      } else if coarseLevelCoarseness == 2 {
        coarseLevelIterations = 4
      } else {
        coarseLevelIterations = 1
      }
      var eCoarse = gaussSeidelSolve(
        r: rCoarse, 
        coarseness: coarseLevelCoarseness,
        iterations: coarseLevelCoarseness)
      
      // Shift to a higher level.
      if coarseLevelCoarseness < 2 {
        eCoarse = multigridCoarseLevel(
          e: eCoarse,
          r: rCoarse,
          fineLevelCoarseness: coarseLevelCoarseness,
          fineLevelIterations: coarseLevelIterations)
      }
      
      // Prolong from coarse to fine.
      eFine = shiftResolution(
        fineGrid: eFine,
        coarseGrid: eCoarse,
        fineLevelCoarseness: fineLevelCoarseness, 
        shiftingUp: false)
      rFine = correctResidual(
        e: eFine,
        r: rFine,
        coarseness: fineLevelCoarseness)
      
      // Smoothing iterations on the fine level.
      let δeFine = gaussSeidelSolve(
        r: rFine,
        coarseness: fineLevelCoarseness,
        iterations: fineLevelIterations)
      for cellID in eFine.indices {
        eFine[cellID] += δeFine[cellID]
      }
      return eFine
    }
    
    // Solves the equation ∇^2 e = r, then returns e.
    func gaussSeidelSolve(
      r: [Float], coarseness: Int, iterations: Int = 1
    ) -> [Float] {
      // Allocate an array for the solution vector.
      let arrayLength = Self.cellCount / (coarseness * coarseness * coarseness)
      var e = [Float](repeating: .zero, count: arrayLength)
      gaussSeidelIteration(e: &e, r: r, coarseness: coarseness, iteration: 0)
      gaussSeidelIteration(e: &e, r: r, coarseness: coarseness, iteration: 1)
      for iterationID in 1..<iterations {
        gaussSeidelIteration(
          e: &e, r: r, coarseness: coarseness, iteration: 2 * iterationID + 0)
        gaussSeidelIteration(
          e: &e, r: r, coarseness: coarseness, iteration: 2 * iterationID + 1)
      }
      return e
    }
    
    // Gauss-Seidel with red-black ordering.
    func gaussSeidelIteration(
      e: inout [Float], r: [Float], coarseness: Int, iteration: Int
    ) {
      let h = Self.h * Float(coarseness)
      let gridSize = Self.gridSize / coarseness
      func createAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
      }
      
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            guard (iteration & 1) == (parity & 1) else {
              continue
            }
            
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(indices: cellIndices)
            
            // Iterate over the faces.
            var faceAccumulator: Float = .zero
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< gridSize) else {
                // Add 'zero' to the accumulator.
                continue
              }
              
              // Add the neighbor's value to the accumulator.
              let neighborAddress = createAddress(indices: neighborIndices)
              if iteration == 0 {
                let neighborValue = r[neighborAddress]
                let λ = h * h / 6
                faceAccumulator += 1 / (h * h) * (-λ * neighborValue)
              } else {
                let neighborValue = e[neighborAddress]
                faceAccumulator += 1 / (h * h) * neighborValue
              }
            }
            
            // Fetch the values to evaluate GSRB_LEVEL(e, R, h).
            let rValue = r[cellAddress]
            
            // Update the error in-place.
            let λ = h * h / 6
            e[cellAddress] = λ * (faceAccumulator - rValue)
          }
        }
      }
    }
    
    // Merges the error vector with the residual.
    func correctResidual(
      e: [Float], r: [Float], coarseness: Int
    ) -> [Float] {
      let h = Self.h * Float(coarseness)
      let gridSize = Self.gridSize / coarseness
      func createAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (gridSize * gridSize) + indices.y * gridSize + indices.x
      }
      
      // Allocate an array for the output.
      let cellCount = gridSize * gridSize * gridSize
      var output = [Float](repeating: .zero, count: cellCount)
      
      // Iterate over the cells.
      for indexZ in 0..<gridSize {
        for indexY in 0..<gridSize {
          for indexX in 0..<gridSize {
            var dotProduct: Float = .zero
            
            // Apply the FMA on the diagonal.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = createAddress(indices: cellIndices)
            let cellValue = e[cellAddress]
            dotProduct += -6 / (h * h) * cellValue
            
            // Iterate over the faces.
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              guard all(neighborIndices .>= 0),
                    all(neighborIndices .< gridSize) else {
                // Add 'zero' to the dot product.
                continue
              }
              
              let neighborAddress = createAddress(indices: neighborIndices)
              let neighborValue = e[neighborAddress]
              dotProduct += 1 / (h * h) * neighborValue
            }
            
            // Update the residual.
            let L2e = dotProduct
            output[cellAddress] = r[cellAddress] - L2e
          }
        }
      }
      return output
    }
    
    // Performs a power-2 shift to a coarser level.
    func shiftResolution(
      fineGrid: [Float], coarseGrid: [Float],
      fineLevelCoarseness: Int, shiftingUp: Bool
    ) -> [Float] {
      let fineGridSize = Self.gridSize / fineLevelCoarseness
      let coarseGridSize = fineGridSize / 2
      func createFineAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (fineGridSize * fineGridSize) +
        indices.y * fineGridSize + indices.x
      }
      func createCoarseAddress(indices: SIMD3<Int>) -> Int {
        indices.z * (coarseGridSize * coarseGridSize) +
        indices.y * coarseGridSize + indices.x
      }
      
      // Create the output grid.
      var output: [Float]
      if shiftingUp {
        let coarseCellCount = coarseGridSize * coarseGridSize * coarseGridSize
        output = [Float](repeating: .zero, count: coarseCellCount)
      } else {
        output = fineGrid
      }
      
      // Iterate over the coarse grid.
      for indexZ in 0..<coarseGridSize {
        for indexY in 0..<coarseGridSize {
          for indexX in 0..<coarseGridSize {
            // Read from the coarse grid.
            let coarseIndices = SIMD3<Int>(indexX, indexY, indexZ)
            let coarseAddress = createCoarseAddress(indices: coarseIndices)
            let coarseValue = coarseGrid[coarseAddress]
            
            // Iterate over the footprint on the finer grid.
            var accumulator: Float = .zero
            for permutationZ in 0..<2 {
              for permutationY in 0..<2 {
                for permutationX in 0..<2 {
                  var fineIndices = 2 &* coarseIndices
                  fineIndices[0] += permutationX
                  fineIndices[1] += permutationY
                  fineIndices[2] += permutationZ
                  let fineAddress = createFineAddress(indices: fineIndices)
                  
                  if shiftingUp {
                    // Read from the fine grid.
                    let fineValue = fineGrid[fineAddress]
                    accumulator += (1.0 / 8) * fineValue
                  } else {
                    // Update the fine grid.
                    output[fineAddress] += coarseValue
                  }
                }
              }
            }
            
            // Update the coarse grid.
            if shiftingUp {
              output[coarseAddress] = accumulator
            }
          }
        }
      }
      return output
    }
  }
  
  // Refactor the multigrid code, fix the bug with iteration count, and
  // convert the solver into the FAS scheme.
  // - Modify the storage of the e-vector, permitting RB ordering with Mehr.
  // - Does it achieve the same convergence rates as the original multigrid?
  // - Does it perform better for the 128x128x128 grid attempting to peak the
  //   V-cycle at 64x64x64?
  //
  // Use this to test out the Mehrstellen discretization.
  // - Check the order of convergence, prove there is O(h^2) scaling.
  // - Implement Mehrstellen without the RHS correction, prove there is O(h^2)
  //   scaling. Is it already better than central differencing?
  // - Prove the correct version has O(h^4) scaling.
  // - Is Mehrstellen more numerically unstable?
  func testFullApproximationScheme() throws {
    // Prepare the solution and RHS.
    var b = Self.createScaledChargeDensity()
    let L2x = Self.applyLaplacianBoundary()
    b = Self.shift(b, scale: -1, correction: L2x)
    var x = [Float](repeating: .zero, count: Self.cellCount)
    
    // Execute the iterations.
    for _ in 0..<20 {
      do {
        let L1x = Self.applyLaplacianLinearPart(x)
        let r = Self.shift(b, scale: -1, correction: L1x)
        let r2 = Self.dot(r, r)
        let residualNorm = r2.squareRoot()
        print("||r|| = \(residualNorm)")
      }
      
      let (red, black) = split(solution: x)
      x = merge(red: red, black: black)
      
      x = relax(sweep: .red, solution: x, rhs: b)
      x = relax(sweep: .black, solution: x, rhs: b)
    }
    
    // Split the solution into red and black halves.
    func split(solution: [Float]) -> (
      red: [Float], black: [Float]
    ) {
      var red = [Float](repeating: .zero, count: solution.count / 2)
      var black = [Float](repeating: .zero, count: solution.count / 2)
      
      // Iterate over the cells.
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            // Read the solution value from memory.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            let cellValue = solution[cellAddress]
            
            // Write the solution value to memory.
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            if isRed {
              red[cellAddress / 2] = cellValue
            } else {
              black[cellAddress / 2] = cellValue
            }
          }
        }
      }
      return (red, black)
    }
    
    // Merge the two halves of the solution.
    func merge(red: [Float], black: [Float]) -> [Float] {
      var solution = [Float](repeating: .zero, count: red.count + black.count)
      
      // Iterate over the cells.
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            // Read the solution value from memory.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            var cellValue: Float
            
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            if isRed {
              cellValue = red[cellAddress / 2]
            } else {
              cellValue = black[cellAddress / 2]
            }
            
            // Write the solution to memory.
            solution[cellAddress] = cellValue
          }
        }
      }
      return solution
    }
    
    // The two types of cells that are updated in alternation.
    enum Sweep {
      case red
      case black
    }
    
    func relax(
      sweep: Sweep,
      solution: [Float],
      rhs: [Float]
    ) -> [Float] {
      // Allocate memory for the written solution values.
      var output = solution
      
      // Iterate over the cells.
      for indexZ in 0..<Self.gridSize {
        for indexY in 0..<Self.gridSize {
          for indexX in 0..<Self.gridSize {
            // Mask out either the red or black cells.
            let parity = indexX ^ indexY ^ indexZ
            let isRed = (parity & 1) == 0
            guard isRed == (sweep == .red) else {
              continue
            }
            
            // Iterate over the faces.
            var Lu: Float = .zero
            for faceID in 0..<6 {
              let coordinateID = faceID / 2
              let coordinateShift = (faceID % 2 == 0) ? -1 : 1
              
              // Locate the neighboring cell.
              var neighborIndices = SIMD3(indexX, indexY, indexZ)
              neighborIndices[coordinateID] += coordinateShift
              
              if all(neighborIndices .>= 0),
                 all(neighborIndices .< Self.gridSize) {
                let neighborAddress = Self
                  .createAddress(indices: neighborIndices)
                let neighborValue = x[neighborAddress]
                Lu += 1 / (Self.h * Self.h) * neighborValue
              }
            }
            
            // Read the cell value from memory.
            let cellIndices = SIMD3(indexX, indexY, indexZ)
            let cellAddress = Self.createAddress(indices: cellIndices)
            let cellValue = solution[cellAddress]
            Lu += -6 / (Self.h * Self.h) * cellValue
            
            // Write the cell value to memory.
            let residual = rhs[cellAddress] - Lu
            let Δt: Float = (Self.h * Self.h) / -6
            output[cellAddress] = cellValue + Δt * residual
          }
        }
      }
      return output
    }
  }
}
