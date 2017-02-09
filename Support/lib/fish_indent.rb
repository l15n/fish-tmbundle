# rubocop: disable AsciiComments
# rubocop: disable Style/HashSyntax

# -- Imports -------------------------------------------------------------------

require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_SUPPORT_PATH'] + '/lib/progress'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/detach'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/save_current_document'

# -- Module --------------------------------------------------------------------

# This module allows us to reformat a file via Fish’s indent function.
module FishIndent
  class << self
    # This function reformats the current TextMate document using +fish_indent+.
    #
    # It works both on saved and unsaved files:
    #
    # 1. In the case of an unsaved files this method will stall until
    #    +fish_indent+ fixed the file. While this process takes place the method
    #    displays a progress bar.
    #
    # 2. If the current document is a file saved somewhere on your disk, then
    #    the method will not wait until +fish_indent+ is finished. Instead it
    #    will run +fish_indent+ in the background. This has the advantage, that
    #    you can still work inside TextMate, while +fish_indent+ reformats the
    #    document.
    def reformat
      unsaved_file = true unless ENV['TM_FILEPATH']
      TextMate.save_if_untitled('fish')
      format_file(locate_fish_indent, unsaved_file)
    end

    private

    def locate_fish_indent
      Dir.chdir(ENV['TM_PROJECT_DIRECTORY'] ||
                File.dirname(ENV['TM_FILEPATH'].to_s))
      fish_indent = ENV['TM_FISH_INDENT'] || 'fish_indent'
      return fish_indent if File.executable?(`which #{fish_indent}`.rstrip)
      TextMate.exit_show_tool_tip(
        'Could not locate \`fish_indent\`. Please make sure that you set' \
        "TM_FISH_INDENT correctly.\nTM_FISH_INDENT: “#{ENV['TM_FISH_INDENT']}”"
      )
    end

    def format_file(fish_indent, unsaved_file)
      filepath = ENV['TM_FILEPATH']
      command = "#{fish_indent} -w \"$TM_FILEPATH\" 2>&1"
      error_message = "Fish Indent was not able to reformat the file: \n\n"
      # We set the `TERM` variable, since otherwise `fish_indent` would display
      # a warning about this variable being unset.
      ENV['TERM'] = 'ansi'
      if unsaved_file
        format_unsaved(command, error_message, filepath)
      else
        format_saved(command, error_message, filepath)
      end
    end

    def format_unsaved(fish_indent_command, error_message, filepath)
      output, success = TextMate.call_with_progress(
        :title => '🐠 Fish Indent', :summary => 'Reformatting File'
      ) do
        [`#{fish_indent_command}`, $CHILD_STATUS.success?]
      end
      TextMate.exit_show_tool_tip(error_message + output) unless success
      TextMate::UI.tool_tip(output) unless output.empty?
      TextMate.exit_replace_document(File.read(filepath))
    end

    def format_saved(fish_indent_command, error_message, filepath)
      TextMate.detach do
        output = `#{fish_indent_command}`
        if $CHILD_STATUS.success?
          output = (":\n\n" + output) unless output.empty?
          message = "✨ Reformatted “#{File.basename(filepath)}”#{output}"
          TextMate::UI.tool_tip(message)
        else
          TextMate::UI.tool_tip(error_message + output)
        end
      end
    end
  end
end
