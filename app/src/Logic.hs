-------------------------------------------------------------------------------
-- |
-- Module       : Logic
--
-- This module contains all the data structures and functions related to the
-- game logics: handling of game states, applying actions to game states and
-- calculating allowed actions.
-- This module does not need to know about IO(), Graphics, generation of maps.
-- It should export: GameState (without constructors), possible actions to take
-- and ways of applying them to the game state, ways to change the game state
-- over the passing of a turn (or a set amount of time), functions to access
-- the Floor and the Entities.
-- It shoud not expose the inner workings of GameState and turn p
--
-- ToDo:
-- - decide if invalid game state changes should return Maybe GameState or an
--   unchanged game state
-------------------------------------------------------------------------------

module Logic
    (
        GameState(),
        TurnAction(..),
        newGame,
        getMap,
        getHero,
        getEnts,
        getTurnNumber,
        getFloorNumber,
        getKillList,
        newHero,
        addEnt,
        stepHero,
        stepEntities,
        step
        )
        where

import Utils
import Entities
import Maps
import Data.List(find,delete)
import AI
import System.Random(RandomGen, randomR,split, random)

data TurnAction = HeroMove Direction |ClimbUp | ClimbDown | Ranged Pos | Rest    deriving (Show,Eq)

---------------------------------------------------------------
data GameState = GameState { hero :: Hero,
                             entities :: [Entity],
                             world :: Floor,
                             turnNumber :: Int,
                             floorNumber :: Int,
                             killList :: [Entity]
                           } deriving Show

getMap :: GameState -> Floor
getMap = world

getHero :: GameState -> Hero
getHero = hero

getEnts :: GameState -> [Entity]
getEnts = entities

getTurnNumber :: GameState -> Int
getTurnNumber = turnNumber

getFloorNumber :: GameState -> Int
getFloorNumber = floorNumber

getKillList :: GameState -> [Entity]
getKillList = killList

---------------------------------------------------------------

newGame :: RandomGen g => g -> GameState
newGame ranGen = GameState {hero=newHero, entities=[], world=ranFloor, turnNumber = 0, floorNumber = 1, killList = []}
    where
        ranFloor = (fst $ random ranGen)::Floor

newHero :: Hero
newHero = Entity {ename="Urist", elives=3, ejob=NoJob, eweapon=NoWeapon, eposition=(5,5), erace=Hero, ebehav=Seek}

placeRandomEnt :: RandomGen g => g -> GameState -> GameState
placeRandomEnt ranGen gameState = addEnt (positionEntity randomEnt validPos) gameState
    where
        (randomEnt, ran1) = random ranGen
        validPos = findRandomSpot ran1 gameState

findRandomSpot :: RandomGen g => g -> GameState -> Pos
findRandomSpot ranGen gameState
    | isPositionWalkable (getMap gameState) newPos     = newPos
    | otherwise                     = findRandomSpot ran2 gameState
        where
            newPos = getRandomEmpty ran1 $ getMap gameState
            -- newPos      = (x,y)
            (ran1,ran') = split ranGen
            (ran2,ran3) = split ran'
            -- (x,ran3)    = randomR (0,xmax) ran2
            -- (y, _)      = randomR (0,ymax) ran3
            -- (xmax,ymax) = fst floor

--Does not check entity position
addEnt :: Entity -> GameState -> GameState
addEnt ent gameState = gameState {entities=entities gameState ++[ent]}

moveHero :: GameState -> Direction -> Maybe GameState
moveHero gameState dir
    | isPositionAttackable gameState (x2,y2)= Just $ doCombat gameState (x2,y2)
    | isPositionWalkable (getMap gameState) (x2,y2)  = Just gameState {hero = moveEntity (hero gameState) dir}
    | otherwise                             = Nothing
        where
            (x1,y1) = getPosition $ getHero gameState
            (x2,y2) = makeMove' (x1,y1) dir

doCombat :: GameState -> Pos -> GameState
doCombat gameState pos = gameState {hero=newHero, entities=newEntities, killList=newKillList}
    where
        (newHero,newEnt) = attack (hero gameState) enemy
        enemy :: Entity
        enemy = case lookupPos pos $ getEnts gameState of
                    Just e  -> e
                    Nothing -> error "attacked an empty position"
        (newEntities,newKillList) = if (getHealth newEnt) > 0 then ((replaceEnt newEnt $ getEnts gameState),killList gameState)
                        -- else delete enemy $ getEnts gameState
                        else (delete enemy $ getEnts gameState, newEnt:(killList gameState))

replaceEnt :: Entity -> [Entity] -> [Entity]
replaceEnt e [] = [e]
replaceEnt e (e1:es)
    | getPosition e == getPosition e1     = e:es
    | otherwise                 = e1: replaceEnt e es

lookupPos :: Pos -> [Entity] -> Maybe Entity
lookupPos pos = find ((==) pos . getPosition)

isPositionAttackable :: GameState -> Pos -> Bool
isPositionAttackable gs pos = isPositionValid (getMap gs) pos &&
                              (Nothing /= (lookupPos pos $ getEnts gs))


climbDown :: RandomGen g => g -> GameState -> GameState
climbDown ranGen gs
    | isOnDownStair     = (newGame ranGen){turnNumber =1 + getTurnNumber gs, floorNumber = 1 + getFloorNumber gs}
    | otherwise         = gs
        where
            isOnDownStair = StairDown == getCell (getMap gs)(getPosition $ getHero gs)

healHero :: GameState -> GameState
healHero gs = gs {hero = (getHero gs) {elives = elives (getHero gs) + 1}}

attackEntity :: GameState -> Direction -> GameState
attackEntity = const

stepHero :: TurnAction -> GameState -> GameState
stepHero (HeroMove STAY) gs = healHero gs
stepHero (Ranged _) gs = gs
stepHero (HeroMove dir) gs = 
        case (newGS) of
            Nothing         -> gs
            Just ngs        -> ngs
        where
            newGS = moveHero gs dir
stepHero _ gs = gs

addNewEnemies :: RandomGen g => g -> GameState -> GameState
addNewEnemies ranGen gs
    | length (getEnts gs) > 3  = gs
    | otherwise             = addNewEnemies ran2 $ placeRandomEnt ran1 gs
        where
            (ran1,ran2) = split ranGen


stepEntities :: RandomGen g => g -> GameState -> GameState
stepEntities ranGen gs = addNewEnemies ranGen $ gs {entities = map (\x-> let m = evalBehaviour x (hero gs) in (if isPositionWalkable (getMap gs) (makeMove' (eposition x) m)  then moveEntity x m else x)) (entities gs)}

step :: RandomGen g => g -> TurnAction -> GameState -> GameState
step ranGen ClimbDown gs = climbDown ranGen gs
step ranGen ta gs = stepEntities ranGen $ stepHero ta gs{turnNumber =1 + getTurnNumber gs}
