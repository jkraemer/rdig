# Extend class File with a content_type method
class File
  
  # mime types and file extensions
  FILE_EXTENSION_MIME_TYPES = {
    'doc'  => 'application/msword',
    'html' => 'text/html',
    'htm'  => 'text/html',
    #'.odt'  => 'application/vnd.oasis.opendocument.text',
    'pdf'  => 'application/pdf',
    'txt'  => 'text/plain',
  }
 
  def content_type
    FILE_EXTENSION_MIME_TYPES[File.extname(self.path).downcase.gsub(/^\./,'')] || 'application/octet-stream'
  end
  
end
