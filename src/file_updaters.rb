# frozen_string_literal: true

require "dependabot/python/file_updater"
require "dependabot/file_updaters"
require "dependabot/file_updaters/base"

module FileUpdatersBaseExtras
  def finalize
    # pass
  end
end

Dependabot::FileUpdaters::Base.class_eval { include FileUpdatersBaseExtras }

module Dependabot
  module Python
    class MultiDepFileUpdater < Dependabot::Python::FileUpdater
      def finalize
        print "Finalize...\n"
        self.updated_dependency_files
      end
    end
  end
end

Dependabot::FileUpdaters.register("pip", Dependabot::Python::MultiDepFileUpdater)