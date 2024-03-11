import XCTest
import Accelerate
import Numerics

final class LinearAlgebraTests: XCTestCase {
  // MARK: - Linear Algebra Functions
  
  // Multiplies two square matrices.
  static func matrixMultiply(
    matrixA: [Float], transposeA: Bool = false,
    matrixB: [Float], transposeB: Bool = false,
    n: Int
  ) -> [Float] {
    var matrixC = [Float](repeating: 0, count: n * n)
    for rowID in 0..<n {
      for columnID in 0..<n {
        var dotProduct: Float = .zero
        for k in 0..<n {
          var value1: Float
          var value2: Float
          if !transposeA {
            value1 = matrixA[rowID * n + k]
          } else {
            value1 = matrixA[k * n + rowID]
          }
          if !transposeB {
            value2 = matrixB[k * n + columnID]
          } else {
            value2 = matrixB[columnID * n + k]
          }
          dotProduct += value1 * value2
        }
        matrixC[rowID * n + columnID] = dotProduct
      }
    }
    return matrixC
  }
  
  // Forms an orthogonal basis from a square matrix's columns.
  static func modifiedGramSchmidt(
    matrix originalMatrix: [Float], n: Int
  ) -> [Float] {
    // Operate on the output matrix in-place.
    var matrix = originalMatrix
    
    func normalize(electronID: Int) {
      var norm: Float = .zero
      for cellID in 0..<n {
        let value = matrix[cellID * n + electronID]
        norm += value * value
      }
      
      let normalizationFactor = 1 / norm.squareRoot()
      for cellID in 0..<n {
        var value = matrix[cellID * n + electronID]
        value *= normalizationFactor
        matrix[cellID * n + electronID] = value
      }
    }
    
    for electronID in 0..<n {
      // Normalize the vectors before taking dot products.
      normalize(electronID: electronID)
    }
    
    for electronID in 0..<n {
      for neighborID in 0..<electronID {
        // Determine the magnitude of the parallel component.
        var dotProduct: Float = .zero
        for cellID in 0..<n {
          let value1 = matrix[cellID * n + electronID]
          let value2 = matrix[cellID * n + neighborID]
          dotProduct += value1 * value2
        }
        
        // Subtract the parallel component.
        for cellID in 0..<n {
          var value1 = matrix[cellID * n + electronID]
          let value2 = matrix[cellID * n + neighborID]
          value1 -= dotProduct * value2
          matrix[cellID * n + electronID] = value1
        }
      }
      
      // Rescale the orthogonal component to unit vector length.
      normalize(electronID: electronID)
    }
    
    return matrix
  }
  
  // Reduce the matrix to tridiagonal form.
  //
  // No intermediate householder reflectors are returned, as this isn't
  // the best algorithm for finding eigenvectors. When debugging, use
  // tridiagonalization as a reference for eigenvalues, and the power method as
  // a reference for eigenvectors.
  static func tridiagonalize(
    matrix originalMatrix: [Float],
    n: Int
  ) -> [Float] {
    var currentMatrixA = originalMatrix
    
    // This requires that n > 1.
    for transformID in 0..<n - 2 {
      // Load the column into the cache.
      var V = [Float](repeating: 0, count: n)
      var columnNorm: Float = .zero
      for rowID in (transformID + 1)..<n {
        let address = rowID * n + transformID
        let entry = currentMatrixA[address]
        V[rowID] = entry
        columnNorm += entry * entry
      }
      columnNorm.formSquareRoot()
      
      // Form the 'v' output of Householder(j,x).
      let oldSubdiagonal = V[transformID + 1]
      let newSubdiagonal = columnNorm * Float((oldSubdiagonal >= 0) ? -1 : 1)
      V[transformID + 1] = 1
      for rowID in (transformID + 2)..<n {
        V[rowID] /= oldSubdiagonal - newSubdiagonal
      }
      
      // Form the 'τ' output of Householder(j,x).
      let T = (newSubdiagonal - oldSubdiagonal) / newSubdiagonal
      
      // Operation 1: VT
      var VT = [Float](repeating: 0, count: n)
      for rowID in 0..<n {
        VT[rowID] = V[rowID] * T
      }
      
      // Operation 2: AVT
      var X = [Float](repeating: 0, count: n)
      for rowID in 0..<n {
        var dotProduct: Float = .zero
        for columnID in 0..<n {
          let address = rowID * n + columnID
          dotProduct += currentMatrixA[address] * VT[columnID]
        }
        X[rowID] = dotProduct
      }
      
      // Operation 3: V^H X
      var VX: Float = .zero
      for rowID in 0..<n {
        VX += V[rowID] * X[rowID]
      }
      
      // Operation 4: X - (1 / 2) VT^H (V^H X)
      var W = [Float](repeating: 0, count: n)
      for rowID in 0..<n {
        W[rowID] = X[rowID] - 0.5 * V[rowID] * T * VX
      }
      
      // Operation 5: A - WV^H - VW^H
      for rowID in 0..<n {
        for columnID in 0..<n {
          let address = rowID * n + columnID
          var entry = currentMatrixA[address]
          entry -= W[rowID] * V[columnID]
          entry -= V[rowID] * W[columnID]
          currentMatrixA[address] = entry
        }
      }
    }
    return currentMatrixA
  }
  
  // Returns the transpose of a square matrix.
  static func transpose(matrix: [Float], n: Int) -> [Float] {
    var output = [Float](repeating: 0, count: n * n)
    for rowID in 0..<n {
      for columnID in 0..<n {
        let oldAddress = columnID * n + rowID
        let newAddress = rowID * n + columnID
        output[newAddress] = matrix[oldAddress]
      }
    }
    return output
  }
  
  // Diagonalizes a tridiagonal matrix with LAPACK divide-and-conquer.
  // Returns the eigenvectors in column-major format, as output by LAPACK.
  static func divideAndConquer(matrix: [Float], n: Int) -> (
    eigenvalues: [Float], eigenvectors: [Float]
  ) {
    // Store the tridiagonal matrix in a compact form.
    var D = [Float](repeating: 0, count: n)
    var E = [Float](repeating: 0, count: n - 1)
    for diagonalID in 0..<n {
      let matrixAddress = diagonalID * n + diagonalID
      let vectorAddress = diagonalID
      D[vectorAddress] = matrix[matrixAddress]
    }
    for subDiagonalID in 0..<n - 1 {
      let rowID = subDiagonalID
      let columnID = subDiagonalID + 1
      let matrixAddress = rowID * n + columnID
      let vectorAddress = rowID
      E[vectorAddress] = matrix[matrixAddress]
    }
    
    // Query the workspace size.
    var JOBZ = CChar(Character("V").asciiValue!)
    var N = Int32(n)
    var LDZ = Int32(n)
    var WORK = [Float](repeating: 0, count: 1)
    var LWORK = Int32(-1)
    var IWORK = [Int32](repeating: 0, count: 1)
    var LIWORK = Int32(-1)
    var INFO = Int32(0)
    sstevd_(
      &JOBZ, &N, nil, nil, nil, &LDZ, &WORK, &LWORK, &IWORK, &LIWORK, &INFO)
    
    // Call into LAPACK.
    var Z = [Float](repeating: 0, count: n * n)
    LWORK = Int32(WORK[0])
    LIWORK = Int32(IWORK[0])
    WORK = [Float](repeating: 0, count: Int(LWORK))
    IWORK = [Int32](repeating: 0, count: Int(LIWORK))
    sstevd_(
      &JOBZ, &N, &D, &E, &Z, &LDZ, &WORK, &LWORK, &IWORK, &LIWORK, &INFO)
    
    // Return the eigenpairs.
    return (eigenvalues: D, eigenvectors: Z)
  }
  
  // MARK: - Tests (Permanent)
  
  // Use the utility function from LAPACK to diagonalize a tridiagonal matrix.
  func testDivideAndConquer() throws {
    // The example sourced from Wikipedia.
    testMatrix([
      4, 1, -2, 2,
      1, 2, 0, 1,
      -2, 0, 3, -2,
      2, 1, -2, -1
    ], n: 4)
    
    var eigenvectors: [Float] = [
      7, 6, 5, 4, 3, 2, 1,
      6, 7, 5, 4, 3, 2, 1,
      2, -1, -1, 1, 2, 6, 8,
      0.1, 0.2, 0.5, 0.5, 0.1, 0.2, 0.5,
      -0.1, 0.2, -0.5, 0.5, -0.1, 0.2, -0.5,
      -1, -2, -3, -5, -7, -9, -10,
      69, 23, 9, -48, 7, 1, 9,
    ]
    eigenvectors = Self.transpose(matrix: eigenvectors, n: 7)
    eigenvectors = Self.modifiedGramSchmidt(matrix: eigenvectors, n: 7)
    
    // Well-conditioned eigenspectra without degenerate clusters.
    testEigenvalues([
      4, 3, 2, 1, 0.1, -1.3, -2.3
    ])
    testEigenvalues([
      4, 3, 2, 1, 0, -1, -2
    ])
    
    // Problematic for the iterative diagonalization experiment.
    testEigenvalues([
      4, 3.01, 3.00, 2.99, 0, -2, -2
    ])
    testEigenvalues([
      4, 3.5, 3, 2, 0, -1, -2
    ])
    testEigenvalues([
      2, 2, 0, -2.99, -3.00, -3.01, -4
    ])
    testEigenvalues([
      2, 1, 0, -2.99, -3.00, -3.01, -4
    ])
    
    // Not problematic for the iterative diagonalization experiment.
    testEigenvalues([
      4, 3.01, 3.00, 2.99, 0, -1, -2
    ])
    testEigenvalues([
      4, 3.5, 3, 2, 0, -2, -2
    ])
    testEigenvalues([
      2, 2, 0, -2, -3, -3.5, -4
    ])
    
    func testEigenvalues(_ eigenvalues: [Float]) {
      var Λ = [Float](repeating: 0, count: 7 * 7)
      for i in 0..<7 {
        let address = i * 7 + i
        let value = eigenvalues[i]
        Λ[address] = value
      }
      let ΣT = eigenvectors
      
      let ΛΣT = Self.matrixMultiply(
        matrixA: Λ, transposeA: false,
        matrixB: ΣT, transposeB: false, n: 7)
      let A = Self.matrixMultiply(
        matrixA: ΣT, transposeA: true,
        matrixB: ΛΣT, transposeB: false, n: 7)
      let AΣT = Self.matrixMultiply(
        matrixA: A, transposeA: false,
        matrixB: ΣT, transposeB: true, n: 7)
      
      for electronID in 0..<7 {
        let expectedEigenvalue = eigenvalues[electronID]
        var actualEigenvalue: Float = .zero
        for cellID in 0..<7 {
          let value = AΣT[cellID * 7 + electronID]
          actualEigenvalue += value * value
        }
        actualEigenvalue.formSquareRoot()
        XCTAssertLessThan(
          expectedEigenvalue.magnitude - actualEigenvalue.magnitude, 1e-4)
      }
      
      testMatrix(A, n: 7)
    }
    
    func testMatrix(_ originalMatrixA: [Float], n: Int) {
      let originalMatrixT = Self.tridiagonalize(matrix: originalMatrixA, n: n)
      let (D, Z) = Self.divideAndConquer(matrix: originalMatrixT, n: n)
      
      // Check that the eigenvectors produce the eigenvalues.
      let HΨ = Self.matrixMultiply(
        matrixA: originalMatrixT, 
        matrixB: Z,
        transposeB: true, n: n)
      for electronID in 0..<n {
        var actualE: Float = .zero
        for cellID in 0..<n {
          let address = cellID * n + electronID
          actualE += HΨ[address] * HΨ[address]
        }
        actualE.formSquareRoot()
        
        let expectedE = D[electronID]
        XCTAssertEqual(actualE, expectedE.magnitude, accuracy: 1e-5)
      }
    }
  }
  
  // This test covers an algorithm for generating bulge chasing sequences.
  func testBulgeChasing() throws {
    testMatrix(n: 3, nb: 2)
    testMatrix(n: 4, nb: 2)
    testMatrix(n: 4, nb: 3)
    testMatrix(n: 6, nb: 2)
    testMatrix(n: 10, nb: 2)
    testMatrix(n: 10, nb: 3)
    testMatrix(n: 10, nb: 4)
    testMatrix(n: 10, nb: 8)
    testMatrix(n: 10, nb: 9)
    testMatrix(n: 11, nb: 2)
    testMatrix(n: 11, nb: 3)
    testMatrix(n: 11, nb: 4)
    testMatrix(n: 11, nb: 8)
    testMatrix(n: 11, nb: 9)
    testMatrix(n: 11, nb: 10)
    testMatrix(n: 19, nb: 5)
    testMatrix(n: 27, nb: 8)
    testMatrix(n: 32, nb: 8)
    testMatrix(n: 33, nb: 8)
    
    func testMatrix(n: Int, nb: Int) {
      var matrixA = [Int](repeating: 0, count: n * n)
      for vectorID in 0..<n {
        let address = vectorID * n + vectorID
        matrixA[address] = 1
        
        for subDiagonalID in 1...nb {
          if vectorID + subDiagonalID < n {
            let addressLower = (vectorID + subDiagonalID) * n + vectorID
            let addressUpper = vectorID * n + (vectorID + subDiagonalID)
            matrixA[addressUpper] = 1
            matrixA[addressLower] = 1
          }
        }
      }
      
      // [sweepID, startColumnID, startRowID, endRowID]
      var bulgeChasingSequence: [SIMD4<Int>] = []
      
      func startSweep(sweepID: Int) {
        let startVectorID = sweepID + 1
        guard startVectorID < n - 1 else {
          fatalError("Attempted a sweep that will not generate any bulges.")
        }
        let endVectorID = min(sweepID + nb + 1, n)
        bulgeChasingSequence.append(SIMD4(
          sweepID, sweepID, startVectorID, endVectorID))
        
        var nextBulgeCornerID: SIMD2<Int>?
        nextBulgeCornerID = applyBulgeChase(
          startColumnID: sweepID,
          startRowID: startVectorID,
          endRowID: endVectorID)
        while nextBulgeCornerID != nil {
          let cornerRowID = nextBulgeCornerID![0]
          let cornerColumnID = nextBulgeCornerID![1]
          let endVectorID = cornerRowID + 1
          let startVectorID = cornerColumnID + nb
          
          if endVectorID - startVectorID > 1 {
            bulgeChasingSequence.append(SIMD4(
              sweepID, cornerColumnID, startVectorID, endVectorID))
            
            nextBulgeCornerID = applyBulgeChase(
              startColumnID: cornerColumnID,
              startRowID: startVectorID,
              endRowID: endVectorID)
          } else {
            nextBulgeCornerID = nil
          }
        }
      }
      
      // Returns the location of the next bulge to chase.
      // - startColumnID: The reflector projected onto the main diagonal.
      // - startRowID: The element ID to pivot on.
      // - endRowID: One past the last element to affect.
      func applyBulgeChase(
        startColumnID: Int,
        startRowID: Int,
        endRowID: Int
      ) -> SIMD2<Int>? {
        // Apply Householder reflections to the first column.
        for rowID in startRowID..<endRowID {
          if rowID != startRowID {
            let addressLower = rowID * n + startColumnID
            let addressUpper = startColumnID * n + rowID
            matrixA[addressLower] = 0
            matrixA[addressUpper] = 0
          }
        }
        
        // Loop until you don't find any more ones.
        var nextBulgeCornerID: SIMD2<Int>? // (row, column)
        for columnID in (startColumnID + 1)..<n {
          var foundOne = false
          for rowID in startRowID..<endRowID {
            let address = rowID * n + columnID
            if matrixA[address] == 1 {
              foundOne = true
            }
          }
          guard foundOne else {
            break
          }
          for rowID in startRowID..<endRowID {
            let addressLower = rowID * n + columnID
            let addressUpper = columnID * n + rowID
            matrixA[addressLower] = 1
            matrixA[addressUpper] = 1
          }
          
          // The column and row ID refer to the coordinates on the other side
          // of the symmetric matrix.
          nextBulgeCornerID = SIMD2(columnID, startRowID)
        }
        return nextBulgeCornerID
      }
      
      guard nb > 1 else {
        // The above chaser failed for this edge case. Bake the zero-operation
        // condition into the algorithm for predicting sequences.
        fatalError("Cannot perform bulge chasing when nb = 1.")
      }
      for sweepID in 0..<max(0, n - 2) {
        startSweep(sweepID: sweepID)
      }
      
      var chasingOperationCursor = 0
      func assertNextOperation(
        sweepID: Int, startColumnID: Int,
        startRowID: Int, endRowID: Int
      ) {
        guard chasingOperationCursor < bulgeChasingSequence.count else {
          XCTFail("Overflowed the chasing sequence buffer.")
          return
        }
        let currentOperation = bulgeChasingSequence[chasingOperationCursor]
        
        XCTAssertEqual(
          sweepID, currentOperation[0],
          "sequence[\(chasingOperationCursor)]/sweepID")
        XCTAssertEqual(
          startColumnID, currentOperation[1],
          "sequence[\(chasingOperationCursor)]/startColumnID")
        XCTAssertEqual(
          startRowID, currentOperation[2],
          "sequence[\(chasingOperationCursor)]/startRowID")
        XCTAssertEqual(
          endRowID, currentOperation[3],
          "sequence[\(chasingOperationCursor)]/endRowID")
        
        chasingOperationCursor += 1
      }
      
      for sweepID in 0..<max(0, n - 2) {
        let startVectorID = sweepID + 1
        var endVectorID = sweepID + nb + 1
        endVectorID = min(endVectorID, n)
        guard endVectorID - startVectorID > 1 else {
          fatalError("Generated empty Householder transform.")
        }
        assertNextOperation(
          sweepID: sweepID, startColumnID: sweepID,
          startRowID: startVectorID, endRowID: endVectorID)
        
        var operationID = 1
        while true {
          let startColumnID = (sweepID - nb + 1) + operationID * nb
          let startVectorID = (sweepID + 1) + operationID * nb
          var endVectorID = (sweepID + nb + 1) + operationID * nb
          endVectorID = min(endVectorID, n)
          
          if endVectorID - startVectorID > 1 {
            assertNextOperation(
              sweepID: sweepID, startColumnID: startColumnID,
              startRowID: startVectorID, endRowID: endVectorID)
          } else {
            break
          }
          operationID += 1
        }
      }
      XCTAssertEqual(chasingOperationCursor, bulgeChasingSequence.count)
    }
  }
  
  // MARK: - Experimental Algorithm Development
  
  // Test the two-stage process for tridiagonalizing a matrix, and the
  // aggregation of the Householder reflectors.
  func testTwoStageTridiagonalization() throws {
    // TODO:
    // - Find an algorithm for programming the order of bulge chases.
    // - Test the full-stack diagonalizer against adversarial edge cases.
    // - Run benchmarks, starting with the unoptimized single-core CPU code.
    //   This marks the beginning of the optimization process, which should
    //   end with GPU acceleration.
    //
    // 1) Extract the custom eigensolver into a standalone function. Transform
    //    the original test into a unit test, operating on the same 7x7 matrix.
    // 2) Migrate the 'diagonalize()' function into the Swift module. Organize
    //    it into potentially separate source files, to make it more workable.
    // 3) Start benchmarking **correctness** of the eigensolver against
    //    `ssyevd_`. Enforce correct behavior for extremely small matrices.
    //    Reproduce the experiment where Accelerate's two-stage eigenvalue
    //    solver failed.
    // 4) Store the Householder transforms in a compact matrix, but don't batch
    //    them together for efficiency yet.
    // 5) Begin the optimization/benchmarking, which should progress from
    //    single-core CPU and to full GPU offloading.
    
    testBlockSize(nb: 1)
    testBlockSize(nb: 2)
    testBlockSize(nb: 3)
    testBlockSize(nb: 4)
    testBlockSize(nb: 5)
    testBlockSize(nb: 6)
    
    func testBlockSize(nb: Int) {
      var originalMatrixA: [Float] = [
        7, 6, 5, 4, 3, 2, 1,
        6, 7, 5, 4, 3, 2, 1,
        2, -1, -1, 1, 2, 6, 8,
        0.1, 0.2, 0.5, 0.5, 0.1, 0.2, 0.5,
        -0.1, 0.2, -0.5, 0.5, -0.1, 0.2, -0.5,
        -1, -2, -3, -5, -7, -9, -10,
        69, 23, 9, -48, 7, 1, 9,
      ]
      let n: Int = 7
      
      // Make the matrix symmetric.
      originalMatrixA = Self.matrixMultiply(
        matrixA: originalMatrixA,
        matrixB: originalMatrixA,
        transposeB: true, n: n)
      
      let (eigenvalues, eigenvectors) = diagonalize(
        matrix: originalMatrixA, n: n, nb: nb)
      
      let expectedEigenvalues: [Float] = [
        0.0011429853, 0.5075689, 0.75631386, 6.188949, 145.55783, 443.30386,
        7871.384
      ]
      let eigenvalueAccuracies: [Float] = [
        1e-4, 1e-3, 1e-3, 1e-3, 1e-3, 1e-3, 1e-2
      ]
      
      var expectedEigenvectors: [[Float]] = []
      expectedEigenvectors.append([
        0.0012315774, 0.09477102, 0.08277881, -0.8589063, -0.49401814,
        0.047964625, -0.0094997585])
      expectedEigenvectors.append([
        -0.40089795, 0.4541109, 0.13252003, 0.43725404, -0.640054,
         0.120887995, -0.0053356886])
      expectedEigenvectors.append([
        -0.55025303, 0.54824287, 0.056886543, -0.26165208, 0.56977874,
         0.016768508, 0.004901767])
      expectedEigenvectors.append([
        0.30370802, 0.07415314, 0.7463128, 0.029480757, 0.14456089,
        0.5677579, -0.034115434])
      expectedEigenvectors.append([
        0.5517132, 0.57923084, -0.51686704, 0.016868684, 0.026573017,
        0.2974512, -0.059032507])
      expectedEigenvectors.append([
        -0.3680466, -0.37356234, -0.38447195, -0.038388584, 0.0019791797,
         0.75624263, 0.06159757])
      expectedEigenvectors.append([
        0.06645671, 0.06063038, 0.019931633, -0.00017843395, -0.0045418143,
        -0.008672804, 0.99569774])
      
      for i in 0..<7 {
        let expected = expectedEigenvalues[i]
        let actual = eigenvalues[i]
        let accuracy = eigenvalueAccuracies[i]
        XCTAssertEqual(actual, expected, accuracy: accuracy)
      }
      
      for i in 0..<7 {
        let expected = expectedEigenvectors[i]
        var actual = [Float](repeating: 0, count: 7)
        for elementID in 0..<7 {
          let address = i * 7 + elementID
          actual[elementID] = eigenvectors[address]
        }
        
        var dotProduct: Float = .zero
        for elementID in 0..<7 {
          dotProduct += expected[elementID] * actual[elementID]
        }
        XCTAssertEqual(dotProduct.magnitude, 1, accuracy: 1e-5)
      }
    }
  }
}

// Decomposes a matrix into its principal components.
//
// Arguments:
// - matrix: symmetric matrix of FP32 numbers.
// - n: number of unknowns to solve for.
// - nb: block size for intermediate band reduction.
//
// Returns:
// - eigenvalues: n-element array of eigenvalues, in ascending order.
// - eigenvectors: column-major matrix of the associated eigenvectors.
func diagonalize(matrix: [Float], n: Int, nb: Int) -> (
  eigenvalues: [Float], eigenvectors: [Float]
) {
  // Allocate main memory allocations.
  let originalMatrixA = matrix
  var currentMatrixA = matrix
  var currentReflectors = [Float](repeating: 0, count: n * n)
  
  // Reduce the matrix to band form, and collect up the reflectors.
  var blockStart: Int = 0
  while blockStart < n - nb {
    // Adjust the loop end, to account for the factorization band offset.
    let blockEnd = min(blockStart + nb, n - nb)
    defer { blockStart += nb }
    
    // Load to panel into the cache, isolating mutations to the matrix A.
    var panel = [Float](repeating: 0, count: nb * n)
    for rowID in blockStart..<blockEnd {
      for columnID in 0..<n {
        let matrixAddress = rowID * n + columnID
        let panelAddress = (rowID - blockStart) * n + columnID
        panel[panelAddress] = currentMatrixA[matrixAddress]
      }
    }
    
    // Allocate cache memory for the reflectors.
    var panelReflectors = [Float](repeating: 0, count: nb * n)
    
    // Generate the reflectors.
    for reflectorID in blockStart..<blockEnd {
      // Factor starting at an offset from the diagonal.
      let bandOffset = reflectorID + nb
      
      // Load the row into the cache.
      var vector = [Float](repeating: 0, count: n)
      for elementID in 0..<n {
        let address = (reflectorID - blockStart) * n + elementID
        vector[elementID] = panel[address]
      }
      
      // Apply preceding reflectors (from this panel) to the column.
      for previousReflectorID in blockStart..<reflectorID {
        // Load the reflector into the cache.
        var reflector = [Float](repeating: 0, count: n)
        for elementID in 0..<n {
          let address = (previousReflectorID - blockStart) * n + elementID
          reflector[elementID] = panelReflectors[address]
        }
        
        // Apply the reflector.
        var dotProduct: Float = .zero
        for elementID in 0..<n {
          dotProduct += reflector[elementID] * vector[elementID]
        }
        for elementID in 0..<n {
          vector[elementID] -= reflector[elementID] * dotProduct
        }
      }
      
      // Zero out the elements above the band offset.
      for elementID in 0..<bandOffset {
        vector[elementID] = 0
      }
      
      // Take the norm of the vector.
      var norm: Float = .zero
      for elementID in 0..<n {
        norm += vector[elementID] * vector[elementID]
      }
      norm.formSquareRoot()
      
      // Modify the vector, turning it into a reflector.
      let oldSubdiagonal = vector[bandOffset]
      let newSubdiagonal = norm * Float((oldSubdiagonal >= 0) ? -1 : 1)
      let tau = (newSubdiagonal - oldSubdiagonal) / newSubdiagonal
      for elementID in 0..<n {
        var element = vector[elementID]
        if elementID == bandOffset {
          element = 1
        } else {
          element /= oldSubdiagonal - newSubdiagonal
        }
        element *= tau.squareRoot()
        vector[elementID] = element
      }
      
      // Store the reflector to the cache.
      for elementID in 0..<n {
        let address = (reflectorID - blockStart) * n + elementID
        panelReflectors[address] = vector[elementID]
      }
    }
    
    // Apply the reflectors to the matrix, from both sides.
    for directionID in 0..<2 {
      for vectorID in 0..<n {
        var vector = [Float](repeating: 0, count: n)
        if directionID == 0 {
          // Load the row into the cache.
          for elementID in 0..<n {
            let address = vectorID * n + elementID
            vector[elementID] = currentMatrixA[address]
          }
        } else {
          // Load the column into the cache.
          for elementID in 0..<n {
            let address = elementID * n + vectorID
            vector[elementID] = currentMatrixA[address]
          }
        }
        
        for reflectorID in blockStart..<blockEnd {
          // Load the reflector into the cache.
          var reflector = [Float](repeating: 0, count: n)
          for elementID in 0..<n {
            let address = (reflectorID - blockStart) * n + elementID
            reflector[elementID] = panelReflectors[address]
          }
          
          // Apply the reflector.
          var dotProduct: Float = .zero
          for elementID in 0..<n {
            dotProduct += reflector[elementID] * vector[elementID]
          }
          for elementID in 0..<n {
            vector[elementID] -= reflector[elementID] * dotProduct
          }
        }
        
        if directionID == 0 {
          // Store the row to main memory.
          for elementID in 0..<n {
            let address = vectorID * n + elementID
            currentMatrixA[address] = vector[elementID]
          }
        } else {
          // Store the column to main memory.
          for elementID in 0..<n {
            let address = elementID * n + vectorID
            currentMatrixA[address] = vector[elementID]
          }
        }
      }
    }
    
    // Store the reflectors to main memory.
    for reflectorID in blockStart..<blockEnd {
      for elementID in 0..<n {
        let cacheAddress = (reflectorID - blockStart) * n + elementID
        let memoryAddress = reflectorID * n + elementID
        currentReflectors[memoryAddress] = panelReflectors[cacheAddress]
      }
    }
  }
  
  print()
  print("Matrix A")
  for rowID in 0..<n {
    for columnID in 0..<n {
      let address = rowID * n + columnID
      var value = currentMatrixA[address]
      if value.magnitude < 1e-3 {
        value = 0
      }
      print(value, terminator: ", ")
    }
    print()
  }
  
  // MARK: - Bulge Chasing
  
  var bulgeReflectors: [[Float]] = []
  
  // Apply the Householder reflector to the entire matrix. This isn't very
  // efficient, but it's correct, which we want for initial debugging.
  func applyBulgeChase(
    sweepID: Int,
    vectorID: Int,
    startElementID: Int,
    endElementID: Int
  ) {
    // Load the row into the cache.
    var vector = [Float](repeating: 0, count: n)
    for elementID in startElementID..<endElementID {
      let address = vectorID * n + elementID
      vector[elementID] = currentMatrixA[address]
    }
    print()
    print("bulge row:", vector)
    
    // Take the norm of the vector.
    var norm: Float = .zero
    for elementID in startElementID..<endElementID {
      norm += vector[elementID] * vector[elementID]
    }
    norm.formSquareRoot()
    
    // Modify the vector, turning it into a reflector.
    let oldSubdiagonal = vector[startElementID]
    let newSubdiagonal = norm * Float((oldSubdiagonal >= 0) ? -1 : 1)
    let tau = (newSubdiagonal - oldSubdiagonal) / newSubdiagonal
    for elementID in startElementID..<endElementID {
      var element = vector[elementID]
      if elementID == startElementID {
        element = 1
      } else {
        element /= oldSubdiagonal - newSubdiagonal
      }
      element *= tau.squareRoot()
      vector[elementID] = element
    }
    print("bulge reflector:", vector)
    
    // Apply the reflector to the matrix, from both sides.
    let reflector = vector
    for directionID in 0..<2 {
      for vectorID in 0..<n {
        var vector = [Float](repeating: 0, count: n)
        if directionID == 0 {
          // Load the row into the cache.
          for elementID in 0..<n {
            let address = vectorID * n + elementID
            vector[elementID] = currentMatrixA[address]
          }
        } else {
          // Load the column into the cache.
          for elementID in 0..<n {
            let address = elementID * n + vectorID
            vector[elementID] = currentMatrixA[address]
          }
        }
        
        // Apply the reflector.
        var dotProduct: Float = .zero
        for elementID in 0..<n {
          dotProduct += reflector[elementID] * vector[elementID]
        }
        for elementID in 0..<n {
          vector[elementID] -= reflector[elementID] * dotProduct
        }
        
        if directionID == 0 {
          // Store the row to main memory.
          for elementID in 0..<n {
            let address = vectorID * n + elementID
            currentMatrixA[address] = vector[elementID]
          }
        } else {
          // Store the column to main memory.
          for elementID in 0..<n {
            let address = elementID * n + vectorID
            currentMatrixA[address] = vector[elementID]
          }
        }
      }
    }
    
    print()
    print("A after applying to both sides")
    for rowID in 0..<n {
      for columnID in 0..<n {
        let address = rowID * n + columnID
        var value = currentMatrixA[address]
        if value.magnitude < 1e-3 {
          value = 0
        }
        print(value, terminator: ", ")
      }
      print()
    }
    
    // Store the reflector to main memory.
    bulgeReflectors.append(reflector)
  }
  
  if nb > 1 {
    for sweepID in 0..<max(0, n - 2) {
      let startVectorID = sweepID + 1
      var endVectorID = sweepID + nb + 1
      endVectorID = min(endVectorID, n)
      guard endVectorID - startVectorID > 1 else {
        fatalError("Generated empty Householder transform.")
      }
      
      // apply operation
      print()
      print("applying operation:", sweepID, sweepID, startVectorID, endVectorID)
      applyBulgeChase(
        sweepID: sweepID, vectorID: sweepID,
        startElementID: startVectorID, endElementID: endVectorID)
      
      var operationID = 1
      while true {
        let startColumnID = (sweepID - nb + 1) + operationID * nb
        let startVectorID = (sweepID + 1) + operationID * nb
        var endVectorID = (sweepID + nb + 1) + operationID * nb
        endVectorID = min(endVectorID, n)
        
        if endVectorID - startVectorID > 1 {
          // apply operation
          print()
          print("applying operation:", sweepID, startColumnID, startVectorID, endVectorID)
          applyBulgeChase(
            sweepID: sweepID, vectorID: startColumnID,
            startElementID: startVectorID, endElementID: endVectorID)
        } else {
          break
        }
        operationID += 1
      }
    }
  }
  
  // MARK: - Validation Testing
  
//    return
  
  // Test: Diagonalize the banded matrix with standard techniques. Acquire
  // the eigenvectors, then back-transform them using the reflectors. Ensure
  // they return the same eigenvalue as expected.
  var (eigenvalues, eigenvectors) = LinearAlgebraTests
    .divideAndConquer(matrix: currentMatrixA, n: n)
  eigenvectors = LinearAlgebraTests.transpose(matrix: eigenvectors, n: n)
  
  print()
  print("eigenvalues from D&C")
  print(eigenvalues)
  
  // Display the eigenvectors before the transformation.
  print()
  print("eigenvectors before transformation")
  for vectorID in 0..<n {
    var vector = [Float](repeating: 0, count: n)
    var eigenvalue: Float = .zero
    let matrixRow = Int.random(in: 0..<n)
    
    for elementID in 0..<n {
      let vectorAddress = elementID * n + vectorID
      let vectorValue = eigenvectors[vectorAddress]
      vector[elementID] = vectorValue
      
      // Read data from the current storage for matrix A.
      let matrixAddress = matrixRow * n + elementID
      let matrixValue = currentMatrixA[matrixAddress]
      eigenvalue += matrixValue * vectorValue
      
    }
    eigenvalue /= vector[matrixRow]
    print("Ψ[\(eigenvalue)]:", vector)
  }
  
  eigenvectors = LinearAlgebraTests.transpose(matrix: eigenvectors, n: n)
  
  // Back-transform the eigenvectors.
  print()
  print("back-transforming eigenvectors")
  for vectorID in 0..<n {
    // Load the vector into the cache.
    var vector = [Float](repeating: 0, count: n)
    for elementID in 0..<n {
      let address = vectorID * n + elementID
      vector[elementID] = eigenvectors[address]
    }
    
    for reflectorID in bulgeReflectors.indices.reversed() {
      // Load the reflector into the cache.
      let reflector = bulgeReflectors[reflectorID]
      
      // Apply the reflector.
      var dotProduct: Float = .zero
      for elementID in 0..<n {
        dotProduct += reflector[elementID] * vector[elementID]
      }
      for elementID in 0..<n {
        vector[elementID] -= reflector[elementID] * dotProduct
      }
    }
    
    for reflectorID in (0..<n).reversed() {
      // Load the reflector into the cache.
      var reflector = [Float](repeating: 0, count: n)
      for elementID in 0..<n {
        let address = reflectorID * n + elementID
        reflector[elementID] = currentReflectors[address]
      }
      
      // Apply the reflector.
      var dotProduct: Float = .zero
      for elementID in 0..<n {
        dotProduct += reflector[elementID] * vector[elementID]
      }
      for elementID in 0..<n {
        vector[elementID] -= reflector[elementID] * dotProduct
      }
    }
    print("v[\(vectorID)]", vector)
    
    // Store the vector to main memory.
    for elementID in 0..<n {
      let address = vectorID * n + elementID
      eigenvectors[address] = vector[elementID]
    }
  }
  
  // Display the eigenvectors after the transformation.
  print()
  print("eigenvectors after transformation")
  for vectorID in 0..<n {
    var vector = [Float](repeating: 0, count: n)
    var eigenvalue: Float = .zero
    let matrixRow = Int.random(in: 0..<n)
    for elementID in 0..<n {
      let vectorAddress = vectorID * n + elementID
      let vectorValue = eigenvectors[vectorAddress]
      vector[elementID] = vectorValue
      
      // Read data from the current storage for matrix A.
      let matrixAddress = matrixRow * n + elementID
      let matrixValue = originalMatrixA[matrixAddress]
      eigenvalue += matrixValue * vectorValue
      
    }
    eigenvalue /= vector[matrixRow]
    print("Ψ[\(eigenvalue)]:", vector)
  }
  
  return (eigenvalues, eigenvectors)
}
