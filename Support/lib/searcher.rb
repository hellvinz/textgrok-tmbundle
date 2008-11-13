#!/usr/bin/env jruby -w
require "singleton"
$LOAD_PATH << "#{ENV["TM_SUPPORT_PATH"]}/lib" 
require "exit_codes" 
require "web_preview" 
require "escape"
require 'java'
require "#{ENV["TM_BUNDLE_SUPPORT"]}/opengrok-0.7/opengrok.jar"
import org.opensolaris.opengrok.configuration.RuntimeEnvironment
import org.opensolaris.opengrok.search.SearchEngine
import org.opensolaris.opengrok.index.Indexer
import org.opensolaris.opengrok.index.IndexChangedListener
import java.util.ArrayList
import java.util.List
import java.lang.Runtime

module JavaIO     
   include_package "java.io"
end

class TextMateLogger
  include IndexChangedListener
  include Singleton
  
  def initialize
    html_header("OpenGrok Indexing #{ENV['TM_CURRENT_WORD']}","Be patient!")
  end
  
  def fileAdded(file,analyzer)
    puts("<br/>added #{file}")
  end
  
  def fileRemoved(file)
    puts("<br/>removed #{file}")
  end
end

class OpenGrokSearcher
  include Singleton
  SEARCH_METHODS = [:definition, :file, :freetext, :history, :symbol]
  def initialize
    @configuration = RuntimeEnvironment.getInstance()
    @project_path = ENV["TM_PROJECT_DIRECTORY"]
    raise if @project_path.empty?
    #configuration.readConfiguration(JavaIO::File.new("/Users/vincent/Documents/projets/groked_god/configuration.xml"))
    @configuration.setDataRoot("#{File.join(@project_path,'.grok/')}")
    @configuration.setSourceRoot(@project_path)
    @configuration.setCompressXref(true)
    @configuration.setCtags("#{ENV["TM_BUNDLE_SUPPORT"]}/ctags/ctags")
    @configuration.setGenerateHtml(false)
    @configuration.setRemoteScmSupported(true)
    @configuration.getIgnoredNames().add(".grok")
  end

  def update_index
    indexer = Indexer.getInstance()
    progress = TextMateLogger.instance
    indexer.prepareIndexer(@configuration,true,false,nil,File.join(@project_path,'.grok/','configuration.xml'),false,false,false,ArrayList.new,ArrayList.new)
    indexer.doIndexerExecution(true,Runtime.getRuntime.availableProcessors(),ArrayList.new,progress)
  end
  
  def method_missing(name, *args, &block)
    raise name.to_s unless SEARCH_METHODS.include? name.to_sym
    @search_engine = SearchEngine.new
    @search_engine.send("set#{name.to_s.capitalize}", args[0])
    @nb_hits = @search_engine.search
    search_output(name)
  end
  
  def search_output(name)
    html_header("OpenGrok search results","#{name} search for #{ENV['TM_CURRENT_WORD']}")
    
    results = ArrayList.new(@nb_hits+1)
    @search_engine.more(0,@nb_hits,results)  
    results.each_with_index do |result,index|
      puts "#{index} - <a href='txmt://open?url=file://#{File.join(@project_path,result.getPath)}&amp;line=#{result.getLineno}' accessKey='#{index}'>#{result.getLine}</a> in #{result.getPath}</br>"
    end
    
  rescue => e
      puts "<pre>#{e.backtrace}</pre>"
  ensure
    html_footer
  end
end
