# 2D-Raymarching-Renderer
Setup:
* copy all of the files into your unity assets folder
* create a unity camera, change the projection to orthographics, set the clear flags to 'Solid Color' and set the background alpha to 0
* put the SDF Generator and Lightmanager 2D scripts on the camera
* Drag the JumpFlood shader into the 'Jump Flood Shader' field on the SDF Generator
* Make a material with the 2D Lighting Shader (or the SDF/Voronoi Visualization shaders) and drag it into the Final Rendering Material field
* To add a light, create a new game object and put the Light 2D script onto it
* To add a wall just add any opaque mesh to the scene