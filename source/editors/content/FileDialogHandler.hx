package editors.content;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;

import haxe.Exception;
import sys.io.File;
import lime.ui.*;
import mohong.TraceManager;

import flixel.FlxBasic;

#if android
import android.Tools as AndroidTools;
import android.Permissions;
import android.callback.CallBack;
#end

@:access(openfl.net.FileReference)

enum abstract FileDialogType(String)
{
    var OPEN = "open";
    var SAVE = "save";
    var OPEN_DIRECTORY = "openDirectory";
}

class FileDialogHandler extends FlxBasic
{
    var _fileRef:FileReferenceCustom;
    var _dialogMode:FileDialogType = OPEN;
    
    #if android
    var _pendingAndroidRequest:Int = -1;
    var _pendingMimeType:String;
    var _pendingFileName:String;
    var _pendingDataToSave:String;
    #end
    
    public function new()
    {
        _fileRef = new FileReferenceCustom();
        _fileRef.addEventListener(Event.CANCEL, onCancelFn);
        _fileRef.addEventListener(IOErrorEvent.IO_ERROR, onErrorFn);
        
        #if android
        CallBack.init();
        CallBack.onActivityResult.add(onAndroidActivityResult);
        #end
        
        super();
    }

    public var onComplete:Void->Void;
    public var onCancel:Void->Void;
    public var onError:Void->Void;

    var _currentEvent:openfl.events.Event->Void;

    public function save(?fileName:String = '', ?dataToSave:String = '', ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
    {
        if(!completed)
            throw new Exception('You must finish previous operation before starting a new one.');

        this._dialogMode = SAVE;
        _startUp(onComplete, onCancel, onError);

        #if android
        _pendingFileName = fileName;
        _pendingDataToSave = dataToSave;
        
        if (fileName != null && fileName.length > 0 && !fileName.contains('.'))
            _pendingFileName += '.json';
        
        var mimeType = getMimeTypeFromFileName(_pendingFileName);
        _pendingMimeType = mimeType;
        
        AndroidTools.createDocument(mimeType, _pendingFileName, AndroidTools.REQUEST_CODE_CREATE_DOCUMENT);
        _pendingAndroidRequest = AndroidTools.REQUEST_CODE_CREATE_DOCUMENT;
        #else
        removeEvents();
        _currentEvent = onSaveComplete;
        _fileRef.addEventListener(Event.SELECT, _currentEvent);
        
        if(fileName != null && fileName.length > 0 && !fileName.contains('.'))
            fileName += '.json';
        
        _fileRef.save(dataToSave, fileName);
        #end
    }

    public function open(?defaultName:String = null, ?title:String = null, ?filter:Array<FileFilter> = null, ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
    {
        if(!completed)
            throw new Exception('You must finish previous operation before starting a new one.');

        this._dialogMode = OPEN;
        _startUp(onComplete, onCancel, onError);
        
        #if android
        var mimeTypes = "*/*";
        if (filter != null && filter.length > 0) {
            var exts = [];
            for (f in filter) {
                var parts = f.extension.split(';');
                for (p in parts) {
                    var ext = p.trim();
                    if (ext.startsWith('*.')) ext = ext.substr(2);
                    exts.push(ext);
                }
            }
            // Convert ALL extensions to MIME types; join with '|' for Android
            if (exts.length > 0) {
                var mimeList:Array<String> = [];
                for (ext in exts) {
                    var mapped = getMimeTypeFromFileName('x.' + ext);
                    if (mapped != null && mapped != "application/octet-stream") {
                        if (!mimeList.contains(mapped))
                            mimeList.push(mapped);
                    } else {
                        // Unknown extension — fall back to */* to show all files
                        mimeList = [];
                        break;
                    }
                }
                if (mimeList.length > 0)
                    mimeTypes = mimeList.join('|');
                else
                    mimeTypes = "*/*";
            } else {
                mimeTypes = "*/*";
            }
        }
        
        _pendingMimeType = mimeTypes;
        AndroidTools.openDocument(mimeTypes, AndroidTools.REQUEST_CODE_OPEN_DOCUMENT);
        _pendingAndroidRequest = AndroidTools.REQUEST_CODE_OPEN_DOCUMENT;
        #else
        removeEvents();
        _currentEvent = onLoadComplete;
        _fileRef.addEventListener(Event.SELECT, _currentEvent);
        
        #if sys
        if(filter == null) filter = [new FileFilter('JSON', 'json')];
        _fileRef.browse(filter);
        #end
        #end
    }

    public function openDirectory(?title:String = null, ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
    {
        if(!completed)
            throw new Exception('You must finish previous operation before starting a new one.');

        this._dialogMode = OPEN_DIRECTORY;
        _startUp(onComplete, onCancel, onError);

        #if android
        // Android doesn't directly support directory picking through SAF like this,
        // but we can use OPEN_DOCUMENT_TREE. Since that's not in the current AndroidTools,
        // we fall back to opening any file type.
        _pendingMimeType = "*/*";
        AndroidTools.openDocument("*/*", AndroidTools.REQUEST_CODE_OPEN_DOCUMENT);
        _pendingAndroidRequest = AndroidTools.REQUEST_CODE_OPEN_DOCUMENT;
        #else
        removeEvents();
        _currentEvent = onLoadDirectoryComplete;
        _fileRef.addEventListener(Event.SELECT, _currentEvent);
        
        #if sys
        _fileRef.browse();
        #end
        #end
    }

    #if android
    function onAndroidActivityResult(data:Dynamic)
    {
        if (_pendingAndroidRequest == -1) return;
        
        if (data == null || data.resultCode == 0) {
            // User cancelled
            _pendingAndroidRequest = -1;
            this.completed = true;
            if (onCancel != null) onCancel();
            return;
        }
        
        var uri:String = data.uri;
        if (uri == null) {
            _pendingAndroidRequest = -1;
            this.completed = true;
            if (onError != null) onError();
            return;
        }
        
        switch (_dialogMode) {
            case SAVE:
                if (_pendingAndroidRequest == AndroidTools.REQUEST_CODE_CREATE_DOCUMENT) {
                    // Write the data to the URI
                    var success = AndroidTools.writeTextToUri(uri, _pendingDataToSave);
                    if (success) {
                        AndroidTools.persistUriPermission(uri);
                        this.path = uri;
                        this.completed = true;
                        TraceManager.info('trace.editor.fileSaved', 'Saved file to: {}', [uri]);
                        if (onComplete != null) onComplete();
                    } else {
                        this.completed = true;
                        if (onError != null) onError();
                    }
                }
                
            case OPEN, OPEN_DIRECTORY:
                if (_pendingAndroidRequest == AndroidTools.REQUEST_CODE_OPEN_DOCUMENT) {
                    var content = AndroidTools.readTextFromUri(uri);
                    if (content != null) {
                        AndroidTools.persistUriPermission(uri);
                        this.data = content;
                        this.path = uri;
                        this.completed = true;
                        TraceManager.info('trace.editor.fileLoaded', 'Loaded file from: {}', [uri]);
                        if (onComplete != null) onComplete();
                    } else {
                        this.completed = true;
                        if (onError != null) onError();
                    }
                }
        }
        
        _pendingAndroidRequest = -1;
    }
    
    function getMimeTypeFromFileName(fileName:String):String
    {
        if (fileName == null) return "application/octet-stream";
        
        var ext = fileName.split('.').pop().toLowerCase();
        return switch (ext) {
            case 'json': 'application/json';
            case 'txt', 'hx', 'hxml': 'text/plain';
            case 'xml': 'application/xml';
            case 'csv': 'text/csv';
            case 'png': 'image/png';
            case 'jpg', 'jpeg': 'image/jpeg';
            case 'gif': 'image/gif';
            case 'wav': 'audio/wav';
            case 'mp3': 'audio/mpeg';
            case 'ogg': 'audio/ogg';
            case 'mp4': 'video/mp4';
            case 'pdf': 'application/pdf';
            case 'zip': 'application/zip';
            case 'seb': 'application/octet-stream';
            default: 'application/octet-stream';
        }
    }
    #end

    public var data:String;
    public var path:String;
    public var completed:Bool = true;
    
    function onSaveComplete(_)
    {
        @:privateAccess
        this.path = _fileRef._trackSavedPath;
        this.completed = true;
        TraceManager.info('trace.editor.fileSaved', 'Saved file to: {}', [path]);

        removeEvents();
        if(onComplete != null) onComplete();
    }

    function onLoadComplete(_)
    {
        @:privateAccess
        this.path = _fileRef.__path;
        #if sys
        this.data = File.getContent(this.path);
        #end
        this.completed = true;
        TraceManager.info('trace.editor.fileLoaded', 'Loaded file from: {}', [path]);

        removeEvents();
        if(onComplete != null) onComplete();
    }

    function onLoadDirectoryComplete(_)
    {
        @:privateAccess
        this.path = _fileRef.__path;
        this.completed = true;
        TraceManager.info('trace.editor.dirLoaded', 'Loaded directory: {}', [path]);

        removeEvents();
        if(onComplete != null) onComplete();
    }

    function onCancelFn(_)
    {
        removeEvents();
        this.completed = true;
        if(onCancel != null) onCancel();
    }

    function onErrorFn(_)
    {
        removeEvents();
        this.completed = true;
        if(onError != null) onError();
    }

    function _startUp(onComplete:Void->Void, onCancel:Void->Void, onError:Void->Void)
    {
        this.onComplete = onComplete;
        this.onCancel = onCancel;
        this.onError = onError;
        this.completed = false;
        this.data = null;
        this.path = null;
        #if android
        _pendingAndroidRequest = -1;
        #end
    }

    function removeEvents()
    {
        if(_currentEvent == null) return;
        _fileRef.removeEventListener(Event.SELECT, _currentEvent);
        _currentEvent = null;
    }

    override function destroy()
    {
        removeEvents();
        #if android
        CallBack.onActivityResult.remove(onAndroidActivityResult);
        #end
        _fileRef = null;
        _currentEvent = null;
        onComplete = null;
        onCancel = null;
        onError = null;
        data = null;
        path = null;
        completed = true;
        super.destroy();
    }
}

class FileReferenceCustom extends FileReference
{
    @:allow(editors.content.FileDialogHandler)
    var _trackSavedPath:String;
    
    override function saveFileDialog_onSelect(path:String):Void
    {
        _trackSavedPath = path;
        super.saveFileDialog_onSelect(path);
    }
}