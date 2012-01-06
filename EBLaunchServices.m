/*
 EBLaunchServices.m
 
 Copyright (c) 2012 eric_bro (eric.broska@me.com)
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "EBLaunchServices.h"
#import <CoreServices/CoreServices.h>

/* Private prototype from the LaunchServices framework */
OSStatus _LSCopyAllApplicationURLs(CFArrayRef *array);

typedef id (^EBMappingBlock)(id obj);


@interface EBLaunchServicesListItem (Private)
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSImage *icon;
@end

@implementation EBLaunchServicesListItem
@synthesize url, name, icon;

- (id)init
{
    if ((self = [super init])) {
        self.name = nil;
        self.url  = nil;
        self.icon = nil;
    } else self = nil;
    
    return self;
}

@end


@interface EBLaunchServices (Private)
+ (NSArray *)mappingArray:(NSArray *)array usingBlock:(EBMappingBlock)block;
+ (NSInteger)indexOfItemWithURL:(NSURL *)url inList:(CFStringRef)list_name;
+ (NSArray *)prepareArray:(NSArray *)array withFormat:(enum EBItemsViewFormat)format;
@end

@implementation EBLaunchServices

#pragma mark Shared Lists

+ (NSArray *)allItemsFromList:(NSString *)list_name
{
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, (CFStringRef)list_name, NULL);
    NSArray *tmp = [(NSArray *)LSSharedFileListCopySnapshot(list, NULL) autorelease];
    CFRelease(list);
    return !tmp ? nil : [EBLaunchServices mappingArray: tmp usingBlock:^id(id obj) {
        EBLaunchServicesListItem *item =[[EBLaunchServicesListItem alloc] init];
        [item setName: (NSString *)LSSharedFileListItemCopyDisplayName((LSSharedFileListItemRef)obj)];
        NSURL *url = nil;
        LSSharedFileListItemResolve((LSSharedFileListItemRef)obj, 0, (CFURLRef *)&url, NULL);
        if (url) [item setUrl: url];
        [item setIcon: [[NSImage alloc] initWithIconRef: 
                        LSSharedFileListItemCopyIconRef((LSSharedFileListItemRef)obj)]];
        return item;
    }];
}

+ (BOOL)addItemWithURL:(NSURL *)url toList:(NSString *)list_name
{
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, (CFStringRef)list_name, NULL);
    if (!list) return NO;
    LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(list, 
                                                                 kLSSharedFileListItemLast, 
                                                                 NULL, NULL, 
                                                                 (CFURLRef)url,
                                                                 NULL, NULL);
    CFRelease(list);
    return item ? (CFRelease(item), YES) : NO;
}

+ (BOOL)removeElementWithIndex:(NSInteger)index fromList:(NSString *)list_name
{
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, (CFStringRef)list_name, NULL);
    NSArray *tmp = (NSArray *)LSSharedFileListCopySnapshot(list, NULL);
    LSSharedFileListItemRef item_to_remove = (LSSharedFileListItemRef)[tmp objectAtIndex: index];
    [tmp release];
    if (!item_to_remove) return NO;
    LSSharedFileListItemRemove(list , item_to_remove);
    CFRelease(list);
    return YES;
}

+ (BOOL)removeElementWithURL:(NSURL *)url fromList:(NSString *)list_name
{
    return [EBLaunchServices removeElementWithIndex: 
            [EBLaunchServices indexOfItemWithURL: url inList: (CFStringRef)list_name]
                                           fromList: list_name];
}

+ (BOOL)clearList:(NSString *)list_name
{
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, (CFStringRef)list_name, NULL);
    BOOL isok = (LSSharedFileListRemoveAllItems(list) == noErr);
    return (CFRelease(list), isok);
}


#pragma mark Applications 

+ (NSArray *)allApplicationsFormattedAs:(enum EBItemsViewFormat)response_format
{
    NSArray *tmp = nil;
    _LSCopyAllApplicationURLs((CFArrayRef *)&tmp);
    return [EBLaunchServices prepareArray: [tmp autorelease] withFormat: response_format];
    
}

+ (NSArray *)allApplicationsAbleToOpenFileExtension:(NSString *)extension 
                                     responseFormat:(enum EBItemsViewFormat)response_format
{
    CFStringRef uttype = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                               (CFStringRef)extension, NULL);
    CFArrayRef bundles = LSCopyAllRoleHandlersForContentType(uttype, kLSRolesAll);
    CFRelease(uttype);
    if (!bundles) return nil;
    return [EBLaunchServices prepareArray: [(NSArray *)bundles autorelease] 
                               withFormat: response_format];
}


+ (NSArray *)allAvailableFileTypesForApplication:(NSString *)full_path
{
    NSArray *all_doc_types = [[NSDictionary dictionaryWithContentsOfFile: full_path] 
                              objectForKey: @"CFBundleDocumentTypes"];
    if ( ! all_doc_types) return nil;
    
    return [EBLaunchServices mappingArray: all_doc_types 
                               usingBlock:^id(NSDictionary * obj) {
                                   /* Use 0 as index because it's highest level of file types' hierarchy */
                                   id tmp =  [[obj objectForKey: @"LSItemContentTypes"] objectAtIndex: 0];
                                   return tmp;
                               }];
}

/* Return only MIMEs defined in LaunchService database */
+ (NSArray *)allAvailableMIMETypesForApplication:(NSString *)full_path
{
    NSArray *all_doc_types = [[NSDictionary dictionaryWithContentsOfFile: full_path] 
                              objectForKey: @"CFBundleDocumentTypes"];
    if ( ! all_doc_types) return nil;
    
    return [EBLaunchServices mappingArray: all_doc_types usingBlock:^id(id obj) {
        
        NSArray * tmp_array = [obj objectForKey: @"LSItemContentTypes"];
        /* If we can't recognize a MIME type for some file type - take a look on it' parent type */
        /* e.g. com.pkware.zip-archive (no MIME type) --> public.zip-archive (MIME is OK)*/
        id value = nil;
        for (NSUInteger i = 0; i < [tmp_array count] && !value; i++) {
            value = (NSString *)UTTypeCopyPreferredTagWithClass((CFStringRef)[tmp_array objectAtIndex: i],
                                                                kUTTagClassMIMEType);
        }
        return value;
    }];
}


+ (NSArray *)allAvailableFileExtensionsForApplication:(NSString *)full_path
{
    NSMutableArray *value = [[NSMutableArray alloc] init];
    
    NSArray *all_doc_types = [[NSDictionary dictionaryWithContentsOfFile: full_path] 
                              objectForKey: @"CFBundleDocumentTypes"];
    if ( ! all_doc_types) return nil;
    [all_doc_types enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [value addObjectsFromArray: [obj objectForKey: @"CFBundleTypeExtensions"]]; 
    }];
    return [value autorelease];
}




#pragma mark Files

#define fileExists(x) ([[NSFileManager defaultManager] fileExistsAtPath: (x)])

+ (NSString *)humanReadableTypeForFile:(NSString *)full_path
{
    if ( ! fileExists(full_path)) return nil;
    FSRef fsref;
    CFStringRef ftype;
    FSPathMakeRef((const UInt8 *)[full_path fileSystemRepresentation], &fsref, NULL);
    LSCopyKindStringForRef(&fsref, &ftype);
    NSString *value = [NSString stringWithString: (NSString *)ftype];
    CFRelease(ftype);
    return value;
}

+ (NSString *)mimeTypeForFile:(NSString *)full_path
{
    if ( ! fileExists(full_path)) return nil;
    
    NSString *extension = [full_path pathExtension];
    if (!extension || [extension isEqualToString: @""]) {
        return nil;
    }
    CFStringRef uttype = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, 
                                                               (CFStringRef)extension, NULL);
    CFStringRef mime = UTTypeCopyPreferredTagWithClass(uttype, kUTTagClassMIMEType);
    return mime ? (NSString *)mime : nil;
}

+ (NSArray *)allAvailableFileExtensionsForUTI:(NSString *)file_type
{
    NSDictionary * tmp_dict = (NSDictionary *)UTTypeCopyDeclaration((CFStringRef)file_type);
    id value = [[tmp_dict valueForKey: @"UTTypeTagSpecification"] 
                valueForKey: @"public.filename-extension"];
    [tmp_dict release];
    
    return [value isKindOfClass:NSClassFromString(@"NSArray")] ? value : [NSArray arrayWithObject: value];
}

+ (NSString *)preferredFileExtensionForMIMEType:(NSString *)mime_type
{
    CFStringRef uttype = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                               (CFStringRef)mime_type, NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uttype, kUTTagClassFilenameExtension);
    return extension ? (NSString *)extension : nil;
}

+ (NSArray *)allAvailableFileExtensionsForMIMEType:(NSString *)mime_type
{
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, 
                                                            (CFStringRef)mime_type, NULL);
    return [EBLaunchServices allAvailableFileExtensionsForUTI: (NSString *)uti];
}

+ (NSArray  *)allAvailableFileExtensionsForPboardType:(NSString *)pboard_type
{
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType,
                                                            (CFStringRef)pboard_type, NULL);
    return [EBLaunchServices allAvailableFileExtensionsForUTI: (NSString *)uti];
}

+ (NSArray *)allAvailableFileExtensionsForFileExtension:(NSString *)extension
{
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, 
                                                            (CFStringRef)extension, NULL);
    return [EBLaunchServices allAvailableFileExtensionsForUTI: (NSString *)uti];
}



#pragma mark Private

+ (NSArray *)prepareArray:(NSArray *)array withFormat:(enum EBItemsViewFormat)format
{
    switch ((int)format) {
        case EBItemsAsPaths: {
            return [EBLaunchServices mappingArray: array usingBlock:^id(id obj) {
                id path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: obj];   
                return path;;
            }];
        }
        case EBItemsAsNames: {
            return [EBLaunchServices mappingArray: array usingBlock:^id(id obj) {
                id name = [[NSFileManager defaultManager] displayNameAtPath:
                           [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: obj]];
                return  name;
            }];
        }
        default:
            //case EBItemsAsURLs:
            return array;
    }
}

+ (NSInteger)indexOfItemWithURL:(NSURL *)url inList:(NSString *)list_name
{
    NSArray *tmp = [EBLaunchServices allItemsFromList: list_name];
    NSInteger idx;    
    idx = [tmp indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [[(EBLaunchServicesListItem *)obj url] isEqualTo: url];
    }];
    return idx;
}

/* Going throw an array's elements doing something with them, and create items for a new array */

+ (NSArray *)mappingArray:(NSArray *)array usingBlock:(EBMappingBlock)block
{
    NSUInteger count = [array count];
    id *objects = malloc(sizeof(objects)*count);
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        objects[idx] = [block(obj) retain];
        if ( ! objects[idx]) objects[idx] = [NSNull null];
    }];
    NSMutableArray *return_value = [NSMutableArray arrayWithArray: 
                                    [NSArray arrayWithObjects: objects count: count]];
    [return_value removeObjectsAtIndexes: 
     [return_value indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj isEqualTo: [NSNull null]];
    }]];
    
    for (NSUInteger i = 0; i < count; i++) {
        [objects[i] release];
    }
    free(objects);
    return (return_value);
}
@end
