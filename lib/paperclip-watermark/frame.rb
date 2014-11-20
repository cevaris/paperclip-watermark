module Paperclip
  class Frame < Processor
    # Handles watermarking of images that are uploaded.
    attr_accessor :current_geometry, :target_geometry, :format, :whiny, :convert_options, :watermark_path, :overlay, :position

    def initialize file, options = {}, attachment = nil
      super
      geometry          = options[:geometry]
      @file             = file
      if geometry.present?
        @crop             = geometry[-1,1] == '#'
      end
      @target_geometry  = Geometry.parse geometry
      @current_geometry = Geometry.from_file @file
      @convert_options  = options[:convert_options]
      @whiny            = options[:whiny].nil? ? true : options[:whiny]
      @format           = options[:format]
      @watermark_path   = options[:watermark_path]
      @position         = options[:position].nil? ? "SouthEast" : options[:position]
      @overlay          = options[:overlay].nil? ? true : false
      @current_format   = File.extname(@file.path)
      @basename         = File.basename(@file.path, @current_format)
    end

    # TODO: extend watermark

    # Returns true if the +target_geometry+ is meant to crop.
    def crop?
      @crop
    end

    # Returns true if the image is meant to make use of additional convert options.
    def convert_options?
      not @convert_options.blank?
    end

    # Performs the conversion of the +file+ into a watermark. Returns the Tempfile
    # that contains the new image.
    def make
      dst = Tempfile.new([@basename, @format].compact.join("."))
      dst.binmode

      command = "convert"
      params = [fromfile]
      params += transformation_command
      params << tofile(dst)
      begin
        success = Paperclip.run(command, params.flatten.compact.collect{|e| "'#{e}'"}.join(" "))
      rescue Paperclip::Errors::CommandNotFoundError
        raise Paperclip::Errors::CommandNotFoundError, "There was an error resizing and cropping #{@basename}" if @whiny
      end

      # If we have a frame image
      if watermark_path
        # Solution
        # 'convert','-define jpeg:size=670x670 /tmp/rsz_frame.png /tmp/test.jpg -gravity center -compose DstOver -composite /tmp/example3.jpg'
        # 'convert',' /tmp/xframe.png /tmp/original.jpg -gravity center -compose DstOver -composite /tmp/example6.jpg'

        # Command :: convert 'http://cdn.festpix-local.com.s3.amazonaws.com/events/watermarks/test2/medium/frame.png?1416499772' '-gravity' 'center' '-compose' 'DstOver' '/var/folders/4r/t68zb9zd3l36jp0954xgyyjr0000gn/T/4ba2592ac2d593d52137659160e2dacb20141120-17236-1hnux120141120-17236-13xgzhs' '/var/folders/4r/t68zb9zd3l36jp0954xgyyjr0000gn/T/4ba2592ac2d593d52137659160e2dacb20141120-17236-1hnux120141120-17236-13xgzhs'
        
        command = "convert"
        params = %W[#{watermark_path} #{tofile(dst)} -gravity center -compose DstOver -composite]
        params << tofile(dst)
        begin
          success = Paperclip.run(command, params.flatten.compact.collect{|e| "'#{e}'"}.join(" "))
        rescue Paperclip::Errors::CommandNotFoundError
          raise Paperclip::Errors::CommandNotFoundError, "There was an error processing the watermark for #{@basename}" if @whiny
        end
      end

      dst
    end

    def fromfile
      File.expand_path(@file.path)
    end

    def tofile(destination)
      File.expand_path(destination.path)
    end

    def transformation_command
      if @target_geometry.present?
        scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
        trans = %W[-resize #{scale}]
        trans += %W[-crop #{crop} +repage] if crop
        trans << convert_options if convert_options?
        trans
      else
        scale, crop = @current_geometry.transformation_to(@current_geometry, crop?)
        trans = %W[-resize #{scale}]
        trans += %W[-crop #{crop} +repage] if crop
        trans << convert_options if convert_options?
        trans
      end
    end
  end
end
