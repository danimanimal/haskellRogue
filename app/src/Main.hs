import Maps
import UI
import Entities
import Utils
import Graphics
import Logic
import System.IO
import System.Random (getStdGen,RandomGen,split)

gameLoop :: RandomGen g => (GameState, g) -> IO()
gameLoop (gameState, ranGen) = do
        if (getHealth $ getHero $ gameState) <= 0 then do
            choice <- do
                drawDeathScreen gameState
                ask "\nYou died!!\nWant to try again y/n" yesNoChoice
            case choice of
                Accept      -> gameLoop (myGame ran1, ran2)
                Deny        -> putStrLn "Goodbye" >> return ()
        else do
            clearAndDraw draw gameState
            command <- readCommand
            case command of
                (NoAction)  -> gameLoop (gameState, ranGen)
                (Quit)      -> do   putStrLn "Goodbye"
                                    return ()
                (TA a)      -> gameLoop (step ran1 a gameState, ran2)
                otherwise   -> do print $ "Unexpected command:" ++ (show command)
                                  gameLoop (gameState, ranGen)
        where
            (ran1,ran2) = split ranGen

myGame :: RandomGen g => g -> GameState
myGame ranGen = newGame ranGen

main :: IO()
main = do
        hSetBuffering stdin NoBuffering
        hSetBuffering stdout NoBuffering
        ranGen <- getStdGen
        gameLoop (myGame ranGen,ranGen)
