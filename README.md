# Density Functional Theory

Goal: Combine a few recent advances in quantum chemistry. Do this with maximum possible CPU utilization and the simplest possible algorithms. Due to its simplicity, all of the code can be ported to OpenCL and Metal.

- Real-space formalism
  - Removes orbital basis sets, drastically simplifying the functional form.
  - Removes FFTs, a bottleneck and library dependency.
  - Most DFT libraries (Gaussian, GAMESS, TeraChem) use the plane-wave formalism. This formalism is well-suited to CPUs, but not GPUs.
- [DeepMind 2021 functional](https://www.science.org/doi/10.1126/science.abj6511) (2021)
  - More accurate than the B3LYP functional used for mechanosynthesis research, or at least not significantly worse.
  - The XC functional is often 90% of the maintenance and complexity of a DFT codebase. DeepMind's neural network makes the XC code ridiculously simple.
  - Provide both the DM21 and DM21mu variants, based on independent reviews of DM21.
- [Dynamic precision for eigensolvers](https://pubs.acs.org/doi/10.1021/acs.jctc.2c00983) (2023)
  - Allows DFT to run on consumer hardware with few FP64 units.
  - Remove the LOBPCG; a 12th-order multigrid already solves the eigenproblem.
  - Attempt to reach convergence without subspace diagonalization.
- Variable-resolution orbitals to accelerate the onset of $O(n)$ scaling.
