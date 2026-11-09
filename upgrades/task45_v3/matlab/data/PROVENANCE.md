# Numeric model provenance

`ur5_reference.mat` contains a numeric, independently assembled UR5 geometry snapshot using public dimensions and axes from:

https://github.com/ros-industrial/universal_robot/blob/kinetic-devel/ur_description/urdf/ur5.urdf.xacro

It includes a fixed `world -> base_link` joint and the `base`, `ee_link`, `tool0` fixed branches. Its reference frame is `world`. Exact pi/2 is used where the source text rounds pi/2 to a decimal. The installed MATLAB model remains authoritative for MATLAB execution: `buildPoeModel` obtains its own fixed transforms, joint axes, limits, joint ordering and base name from the actual rigidBodyTree. No Modern Robotics source code is copied or required.

`ur5_spheres.csv` contains our numeric sphere approximations of the public upstream collision meshes (`base`, `shoulder`, `upperarm`, `forearm`, `wrist1`, `wrist2`, `wrist3`). No STL/DAE meshes are redistributed in this package. Each mesh's convex hull is enclosed by a PCA-axis cylinder. Axial sphere spacing is at most 0.035 m; radius is `sqrt(rho^2 + (h/2)^2) + 0.003 m`, where rho bounds the transverse distance of all vertices and h is the actual spacing. This covers the whole cylinder, including axial gaps. The ee_link box is covered by its circumsphere plus 3 mm.

The root/base collision envelope is excluded only when it belongs to the rigidBodyTree base rather than a body; the demonstration cube is remote from this stationary base. MATLAB's final independent collision check includes the loaded model geometry.

`upstream_package.xml` is the original upstream package metadata and declares BSD licensing. The public model credits ROS-Industrial/Universal Robots; see its authors and maintainers in that file. Generated numeric envelopes and original PoE/STOMP code in this work package are identified separately from those upstream assets.

If MATLAB's installed geometry is changed, sphere-model coverage must be re-established. The final MATLAB `checkCollision` gate prevents an unchecked sphere proxy from being reported as a validated mesh result.

## KINOVA Gen3 numeric envelopes

`kinova_spheres.csv` was generated from the installed R2023b `kinovaGen3` collision geometry using `buildKinovaSpheres.m`. Each body is copied into a one-body tree with a fixed identity joint. Public `show(...,'Collisions','on','Visuals','off')` graphics patch vertices supply the body-local collision mesh, including its local transform. This avoids depending on private robot geometry properties.

The same conservative PCA-cylinder cover uses spacing at most 0.015 m and zero additional padding, yielding 106 spheres across all eight moving/fixed tool bodies. The stationary root/base is excluded from the optimization proxy; MATLAB's independent final check uses the loaded model collision geometry. `KINOVA_LICENSE.txt` preserves the upstream notices supplied with the installed robot model. Raw meshes and MathWorks software are not included.

To regenerate under R2023b, run `buildKinovaSpheres(fullfile('data','kinova_spheres.csv'))` from `matlab`. A changed robot model requires revalidation. In the original Task 1 goal, the conservative sphere envelope overlaps the box although actual collision meshes are separated by approximately 6.90 mm; Task 1 therefore reports the proxy overlap explicitly and accepts only a dense actual-mesh collision-free path. This special case is not used for UR5 Tasks 2/3.
