/*
 EBLaunchServices.h
 
 Copyright (c) 2012 eric_bro (eric.broska@me.com)
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.*/

//  This class allows you to deal with some LaunchServices functions (such a Shared Lists, files types and extension information) via ligth-weight API.
//  You can find the list of all availabe Shared Lists below:
//  
//  kLSSharedFileListFavoriteVolumes
//  kLSSharedFileListFavoriteItems
//  kLSSharedFileListRecentApplicationItems
//  kLSSharedFileListRecentDocumentItems
//  kLSSharedFileListRecentServerItems
//  kLSSharedFileListSessionLoginItems
//  kLSSharedFileListGlobalLoginItems

#import <Cocoa/Cocoa.h>

enum EBItemsViewFormat {
    EBItemsAsBundleIDs,
    EBItemsAsPaths,
    EBItemsAsNames
}EBItemsViewFormat;

@interface EBLaunchServices : NSObject

/* Shared lists */
+ (NSArray *)allItemsFromList:(NSString *)list_name;
+ (BOOL)addItemWithURL:(NSURL *)url toList:(NSString *)list_name;
+ (BOOL)removeElementWithIndex:(NSInteger)index fromList:(NSString *)list_name;
+ (BOOL)removeElementWithURL:(NSURL *)url fromList:(NSString *)list_name;
+ (BOOL)clearList:(NSString *)list_name;

/* Application abilities */
+ (NSArray *)allApplicationsFormattedAs:(enum EBItemsViewFormat)response_format;
+ (NSArray *)allApplicationsAbleToOpenFileExtension:(NSString *)extension responseFormat:(enum EBItemsViewFormat)response_format;

+ (NSArray *)allAvailableFileTypesForApplication:(NSString *)full_path;
+ (NSArray *)allAvailableMIMETypesForApplication:(NSString *)full_path;
+ (NSArray *)allAvailableFileExtensionsForApplication:(NSString *)full_path;

/* General file info - MIME type, preferred extension and human-readable type*/
+ (NSString *)humanReadableTypeForFile:(NSString *)full_path;
+ (NSString *)mimeTypeForFile:(NSString *)full_path;
+ (NSString *)preferredFileExtensionForMIMEType:(NSString *)mime_type;

+ (NSArray *)allAvailableFileExtensionsForUTI:(NSString *)file_type;
+ (NSArray *)allAvailableFileExtensionsForMIMEType:(NSString *)mime_type;
+ (NSArray *)allAvailableFileExtensionsForPboardType:(NSString *)pboard_type;
+ (NSArray *)allAvailableFileExtensionsForFileExtension:(NSString *)extension;

@end

@interface EBLaunchServicesListItem : NSObject 
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) NSImage *icon;
@end