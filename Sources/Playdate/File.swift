import CPlaydate

var fileAPI: playdate_file { playdateAPI.file.unsafelyUnwrapped.pointee }

/// Access the Playdate file system.
public enum File {}