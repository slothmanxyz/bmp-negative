module BMP where
import Data.Word(Word8)
import Data.Bits
import Data.List.Split

-- Alias for Word8. Word8 is essentially an 8bit unsigned Integral.
type Byte = Word8

-- Hexa-decimal to decimal Int for parsing Header
toInt :: [Byte] -> Int
toInt [] = 0
toInt [x] = fromIntegral x
toInt (x:xs) = fromIntegral x + (shift (toInt xs) 8)

-- Convenient Alias'
type BmpImage   = (Header,PixelData)
type Header     = [Byte]
type PixelData  = [Row]
type Row        = (RGB,Padding)
type RGB        = [Byte]
type Padding    = [Byte]

-- Parsing Image given image width and pixel data row size
-- Split the Byte array at the offset
-- Need to consider all list lengths for functional safety
-- The Pixel Data is rowSize * height bytes from the offset
-- The bytes afterwards are negligible
toBmpImage :: Int -> Int -> Int -> [Byte] -> BmpImage
toBmpImage width height offSet = (\(h,p)->(h,toPixelData width rowSize $ take (rowSize * height) p)) . splitAt offSet
  where rowSize = div (width * 24 + 31) 32 * 4

-- Each row is rowSize bytes long
-- For each row, the padding is the last (rowSize - 3*width) bytes
-- i.e. the RGB bytes are the first 3*width bytes
toPixelData :: Int -> Int -> [Byte] -> PixelData
toPixelData width rowSize = map (splitAt $3*width) . chunksOf rowSize

-- simply concatenate everything
toByteArray :: BmpImage -> [Byte]
toByteArray (h,p) = (++) h $ concat $ map (uncurry (++)) p

-- Inverting the Color Bytes. The padding stays the same
invertPixels :: PixelData -> PixelData
invertPixels = map (\(x,y)-> (map complement x , y))

-- Invert enitre image
invertImage :: BmpImage -> BmpImage
invertImage (h,p) = (h, invertPixels p)

-- Checking constraints on BMP
-- ByteArray to Either an Error or a BmpImage
-- Functionally problematic. Consider all List lengths
-- The length limit of 54 is somewhat of an arbitrary value. From what I understand, DIB header ends at 54th byte
parseImage :: [Byte] -> Either String BmpImage
parseImage image
  | length image < 54             = Left "byte array shorter than 54: Not long enough to be parsed\n Check whether your image is a valid bmp image"
  | header_field /= (66+77*256)   = Left "bogus header info: Check whether your image is a valid bmp"
  | compression_field /= 0        = Left "compressed BMP: can only accept uncompressed BMP"
  | bpp /= 24                     = Left "not 24bpp: can only support 24bpp images"
  | otherwise                     = Right $ toBmpImage width height offSet image
  where header_field      = toInt $ take 2 image
        offSet            = toInt $ take 4 $ drop 10 image  -- where the pixel data starts
        width             = toInt $ take 4 $ drop 18 image  -- pixel width of image
        height            = toInt $ take 4 $ drop 22 image  -- pixel height of image
        bpp               = toInt $ take 2 $ drop 28 image  -- bits per pixel of image
        compression_field = toInt $ take 4 $ drop 30 image  -- compression data of bmp