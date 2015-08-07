# ExtractorTube
### WIP WIP WIP
ExtractorTube allows for the extracting of a YouTube media's direct streaming URLs (not the download url). In theory, it should work for both VEVO and non-VEVO content.

## Todo
* Execute the signature decryption function
* Decrypt signatures

## Examples
```objc
ExtractorTube *extractor = [ExtractorTube sharedExtractor];
[extractor search:@"mWRsgZuwf_8" success:^(NSString *response) {
  
} failure:^(NSString *error) {
            
}];
```
