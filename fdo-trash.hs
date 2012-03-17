import System.Environment(getArgs,getProgName)
import System.Console.GetOpt(getOpt,ArgOrder(..),OptDescr(..),ArgDescr(..),usageInfo)
import System.FilePath.Posix((</>),(<.>))
import System.Directory(getDirectoryContents)
import Data.Maybe(catMaybes)
import Data.Time(getCurrentTimeZone,getCurrentTime,utcToLocalTime)
import Data.List(sort,intercalate)
import Freedesktop.Trash(TrashFile(..),genTrashFile,trashGetOrphans,getTrashPaths,formatTrashDate,encodeTrashPath)
import Control.Monad(when)

actions =
    [ ("purge", fdoPurge)
    , ("rm", fdoRm)
    , ("unrm", fdoUnRm)
    ]

--compilerOpts :: [String] -> IO (Options, [String])
parseOpts defaultOptions options exe argv =
    case getOpt Permute options argv of
        (o,n,[]  ) -> return (foldl (flip id) defaultOptions o, n)
        (_,_,errs) -> ioError (userError (concat errs ++ usageInfo header options))
    where header = "Usage: " ++ exe ++ " [OPTION...] parameters..."

--Rm
rmFile realPath trashFile = do
    timeZone <- getCurrentTimeZone
    putStrLn "rename:"
    print (encodeTrashPath realPath)
    print trashFile
    print $ formatTrashDate (utcToLocalTime timeZone $ deleteTime trashFile)

data RmOptions = RmOptions
    { rmTimeOffset :: Double
    , rmVersion    :: Bool
    , rmHelp       :: Bool
    } deriving(Show)

rmDefaults = RmOptions
    { rmTimeOffset = 0
    , rmVersion = False
    , rmHelp = False
    }

rmOptions =
    [ Option ['V'] ["version"] (NoArg (\opts -> opts{rmVersion=True})) "Show version number"
    , Option ['h'] ["help"] (NoArg (\opts -> opts{rmHelp=True})) "Print help"
    , Option ['t'] ["time"] (ReqArg  (\secs opts -> opts{rmTimeOffset=read secs}) "secs")
        ("Specify time offset, default: " ++ (show $ rmTimeOffset rmDefaults))
    ]

fdoRm args = do
    (myOpts, realArgs) <- parseOpts rmDefaults rmOptions "fdo-rm" args
    print myOpts
    when (null realArgs) $ ioError (userError "No files specified")

    now <- getCurrentTime
    let time = now
    (iPath,fPath) <- getTrashPaths
    let file = TrashFile
            (iPath </> head args)
            (fPath </> head args)
            (head realArgs)
            time
            0
    rmFile (head realArgs) file

--Purge
data PurgeOptions = PurgeOptions
    { purgeThreshold :: Double
    , purgeAgePow    :: Double
    , purgeSizePow   :: Double
    , purgeVersion   :: Bool
    , purgeHelp      :: Bool
    } deriving(Show)

purgeDefaults = PurgeOptions
    { purgeThreshold = 10**6
    , purgeAgePow = 1
    , purgeSizePow = 0.1
    , purgeHelp = False
    , purgeVersion = False
    }

purgeOptions =
    [ Option ['V'] ["version"] (NoArg (\opts -> opts{purgeVersion=True})) "Show version number"
    , Option ['h'] ["help"] (NoArg (\opts -> opts{purgeHelp=True})) "Print help"
    , Option ['a'] ["age"] (ReqArg  (\secs opts -> opts{purgeThreshold=read secs}) "secs")
        ("Specify maximium file age default: " ++ (show $ purgeThreshold purgeDefaults))
    , Option ['A'] ["age-power"] (ReqArg (\pow opts -> opts{purgeAgePow=read pow}) "pow")
        ("Specify age power for threshold formula size^sizepow*age^agepow, default: " ++
        (show $ purgeAgePow purgeDefaults))
    , Option ['S'] ["size-power"] (ReqArg (\pow opts -> opts{purgeSizePow=read pow}) "pow")
        ("Specify size power for threshold formula size^sizepow*age^agepow, default: "
        ++ (show $ purgeSizePow purgeDefaults))
    ]

fdoPurge args = do
    (myOpts, _) <- parseOpts purgeDefaults purgeOptions "fdo-purge" args
    (iPath,fPath) <- getTrashPaths
    timeZone <- getCurrentTimeZone
    infoFiles <- fmap (sort.filter (\x -> x /= ".." && x /= ".")) $ getDirectoryContents iPath
    dataFiles <- fmap (sort.filter (\x -> x /= ".." && x /= ".")) $ getDirectoryContents fPath
    let (iExtra,dExtra) = trashGetOrphans infoFiles (sort $ map (<.>"trashinfo") dataFiles)
    print (iExtra,dExtra)
    ayx <- fmap catMaybes $ mapM (genTrashFile iPath fPath timeZone) dataFiles
    print myOpts
    print args
    print ayx

--Unrm
data UnRmOptions = UnRmOptions
    { unRmOrigDir  :: Bool
    , unRmVersion  :: Bool
    , unRmHelp     :: Bool
    , unRmOutFile  :: Maybe String
    , unRmSelect   :: Maybe String
    } deriving(Show)

unRmDefaults = UnRmOptions
    { unRmOrigDir = False
    , unRmHelp    = False
    , unRmVersion = False
    , unRmOutFile = Nothing
    , unRmSelect  = Nothing
    }

unRmOptions =
    [ Option ['V'] ["version"] (NoArg (\opts -> opts{unRmVersion=True})) "Show version number"
    , Option ['h'] ["help"] (NoArg (\opts -> opts{unRmHelp=True})) "Print help"
    , Option ['O'] ["original-name"] (NoArg  (\opts -> opts{unRmOrigDir=True}))
        "output file to original path, default: ., conflicts with -o"
    , Option ['o'] ["output-file"] (ReqArg (\out opts -> opts{unRmOutFile=Just out}) "filepath")
        "Specify output file, conflicts with -O"
    , Option ['s'] ["select"] (ReqArg (\index opts -> opts{unRmSelect=Just $ read index}) "index")
        "Select file with index if multiple files match"
    ]


fdoUnRm args = do
    (myOpts, realArgs) <- parseOpts unRmDefaults unRmOptions "fdo-unrm" args
    print myOpts
    print realArgs
    putStrLn "TODO"

--Main
main :: IO ()
main = do
    args <- getArgs
    exe <- getProgName
    let actionsStr = intercalate "|" $ map fst actions
        thisAction = maybe
            ( if (null args)
                then Nothing
                else maybe
                    (Nothing)
                    (\x -> Just (tail args, x))
                    (lookup (args !! 0) actions) )
            (\x -> Just (args,x))
            (lookup (drop 4 exe) actions)

    maybe
        (putStrLn $ "No action specified\nUsage: " ++ exe ++ " <" ++ actionsStr ++ "> params")
        (\(a,f) -> f a)
        thisAction

