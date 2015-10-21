module Example3 where

import Prelude
import Graphics.WebGLAll
import qualified Data.Matrix4 as M
import qualified Data.Matrix as M
import qualified Data.Vector3 as V3
import Control.Monad.Eff.Alert
import qualified Data.ArrayBuffer.Types as T
import qualified Data.TypedArray as T

import Control.Monad.Eff
import Control.Monad
import Control.Monad.Eff.Console
import Data.Tuple
import Data.Date
import Data.Time
import Data.Maybe
import Math hiding (log)
import Data.Int (toNumber)

shaders :: Shaders {aVertexPosition :: Attribute Vec3, aVertexColor :: Attribute Vec3,
                      uPMatrix :: Uniform Mat4, uMVMatrix:: Uniform Mat4}
shaders = Shaders

  """precision mediump float;

  varying vec4 vColor;

  void main(void) {
    gl_FragColor = vColor;
      }
  """

  """
      attribute vec3 aVertexPosition;
      attribute vec4 aVertexColor;

      uniform mat4 uMVMatrix;
      uniform mat4 uPMatrix;

      varying vec4 vColor;

      void main(void) {
          gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
          vColor = aVertexColor;
      }
  """

type State = {
                context :: WebGLContext,
                shaderProgram :: WebGLProg,
                aVertexPosition :: Attribute Vec3,
                aVertexColor  :: Attribute Vec3,
                uPMatrix :: Uniform Mat4,
                uMVMatrix :: Uniform Mat4,
                buf1 :: Buffer T.Float32,
                buf1Colors :: Buffer T.Float32,
                buf2 :: Buffer T.Float32,
                buf2Colors :: Buffer T.Float32,
                lastTime :: Maybe Number,
                rTri :: Number,
                rSquare :: Number
            }

main :: forall eff. Eff (console :: CONSOLE, alert :: Alert, now :: Now) Unit
main =
  runWebGL
    "glcanvas"
    (\s -> alert s)
      \ context -> do
        log "WebGL started"
        withShaders shaders
                    (\s -> alert s)
                      \ bindings -> do
          buf1 <- makeBufferFloat [0.0,  1.0,  0.0,
                              (-1.0), (-1.0),  0.0,
                              1.0, (-1.0),  0.0]
          buf1Colors <- makeBufferFloat  [
                              1.0, 0.0, 0.0, 1.0,
                              0.0, 1.0, 0.0, 1.0,
                              0.0, 0.0, 1.0, 1.0
                              ]
          buf2 <- makeBufferFloat [1.0,  1.0,  0.0,
                             (-1.0), 1.0,  0.0,
                              1.0, (-1.0),  0.0,
                             (-1.0), (-1.0),  0.0]
          buf2Colors <- makeBufferFloat
                             [0.5, 0.5, 1.0, 1.0,
                             0.5, 0.5, 1.0, 1.0,
                             0.5, 0.5, 1.0, 1.0,
                             0.5, 0.5, 1.0, 1.0]
          clearColor 0.0 0.0 0.0 1.0
          enable DEPTH_TEST
          let state = {
                        context : context,
                        shaderProgram : bindings.webGLProgram,
                        aVertexPosition : bindings.aVertexPosition,
                        aVertexColor : bindings.aVertexColor,
                        uPMatrix : bindings.uPMatrix,
                        uMVMatrix : bindings.uMVMatrix,
                        buf1 : buf1,
                        buf1Colors : buf1Colors,
                        buf2 : buf2,
                        buf2Colors : buf2Colors,
                        lastTime : Nothing,
                        rTri : 0.0,
                        rSquare : 0.0
                      }
          tick state

tick :: forall eff. State ->  EffWebGL (now :: Now |eff) Unit
tick state = do
--  trace ("tick: " ++ show state.lastTime)
  drawScene state
  state' <- animate state
  return unit
  requestAnimationFrame (tick state')

unpackMilliseconds :: Milliseconds -> Number
unpackMilliseconds (Milliseconds n) = n

animate ::  forall eff. State -> EffWebGL (now :: Now |eff) State
animate state = do
  timeNow <- liftM1 (unpackMilliseconds <<< toEpochMilliseconds) now
  case state.lastTime of
    Nothing -> return state {lastTime = Just timeNow}
    Just lastt ->
      let elapsed = timeNow - lastt
      in return state {lastTime = Just timeNow,
                       rTri = state.rTri + (90.0 * elapsed) / 1000.0,
                       rSquare = state.rSquare + (75.0 * elapsed) / 1000.0}

drawScene :: forall eff. State  -> EffWebGL (now :: Now |eff) Unit
drawScene s = do
      canvasWidth <- getCanvasWidth s.context
      canvasHeight <- getCanvasHeight s.context
      viewport 0 0 canvasWidth canvasHeight
      clear [COLOR_BUFFER_BIT, DEPTH_BUFFER_BIT]

      let pMatrix = M.makePerspective 45.0 (toNumber canvasWidth / toNumber canvasHeight) 0.1 100.0
      setUniformFloats s.uPMatrix (M.toArray pMatrix)
      let mvMatrix =
          M.rotate (degToRad s.rTri) (V3.vec3' [0.0, 1.0, 0.0])
            $ M.translate  (V3.vec3 (-1.5) 0.0 (-7.0)) M.identity

      setUniformFloats s.uMVMatrix (M.toArray mvMatrix)

      bindBufAndSetVertexAttr s.buf1Colors s.aVertexColor
      drawArr TRIANGLES s.buf1 s.aVertexPosition

      let mvMatrix =
          M.rotate (degToRad s.rSquare) (V3.vec3' [1.0, 0.0, 0.0])
            $ M.translate  (V3.vec3 (1.5) 0.0 (-7.0)) M.identity
      setUniformFloats s.uMVMatrix (M.toArray mvMatrix)

      bindBufAndSetVertexAttr s.buf2Colors s.aVertexColor
      drawArr TRIANGLE_STRIP s.buf2 s.aVertexPosition

-- | Convert from radians to degrees.
radToDeg :: Number -> Number
radToDeg x = x/pi*180.0

-- | Convert from degrees to radians.
degToRad :: Number -> Number
degToRad x = x/180.0*pi
