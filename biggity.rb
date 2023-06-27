#!/usr/bin/env -S ruby --jit
# frozen_string_literal: true

require 'fileutils'
require 'find'
require 'logger'
require 'pathname'
require 'shellwords'

# Module for finding host OS
module OS
  def self.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def self.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def self.unix?
    !OS.windows?
  end

  def self.linux?
    OS.unix? and !OS.mac?
  end

  def self.jruby?
    RUBY_ENGINE == 'jruby'
  end
end


B_IN_KB = 1024
USERS_SRC_FILENAME = 'Users'
ROOT_FILENAME = 'Root'
USERS_DEST_FILENAME = '7Profiles'
DEFAULT_DEST_ROOT = if OS.windows?
                      'X:\\'
                    elsif OS.linux?
                      '/zfspool/'
                    else
                      ''
                    end


# Copy all user folders into subdirectory `7Profiles` and root files into
# subdirectory `Root`, both under the main dest dir. Returns bytes transferred.
def windows_backup(abs_src_dir, dest_dir)
  users_src_pathname = File.join(abs_src_dir, USERS_SRC_FILENAME)

  # The destination parent dir of the user folders is called 7Profiles because
  # that's what Biggity calls it. Retained for compatibility.
  users_dest_pathname = File.join(dest_dir, USERS_DEST_FILENAME)
  root_dest_pathname = File.join(dest_dir, ROOT_FILENAME)

  FileUtils.mkpath(users_dest_pathname)
  FileUtils.mkpath(root_dest_pathname)

  # Backup the Users files first as they're generally more important to the
  # customer
  users_bytes_transferred = basic_backup(users_src_pathname, users_dest_pathname)
  root_bytes_transferred = basic_backup(abs_src_dir, root_dest_pathname, [USERS_SRC_FILENAME])

  users_bytes_transferred + root_bytes_transferred
end


# Takes the absolute path of the source directory and copies filetree, skipping
# empty directories. `ignore` is a list of paths relative from the source
# directory to skip. Returns bytes transferred.
def basic_backup(abs_src_dir, dest_dir, ignore = [])
  total_bytes_transferred = 0
  Find.find(abs_src_dir) do |path|
    # Path is relative to CWD
    # Because `path` is relative from CWD, we need to find the path of the
    # same file relative from the source directory
    pathname_obj = Pathname.new(File.absolute_path(path))
    rel_path = pathname_obj.relative_path_from(abs_src_dir)

    # Skip paths that are in the ignore array
    Find.prune if ignore.include?(rel_path.to_path)

    next unless File.file?(path)

    rel_parent_dir = File.dirname(rel_path)
    abs_dest_parent_dir = File.join(dest_dir, rel_parent_dir)
    abs_dest_path = File.join(dest_dir, rel_path)

    FileUtils.mkpath(abs_dest_parent_dir)

    file_size = File.size(path)

    loginfo("#{path} to #{abs_dest_path}, size #{file_size}")
    begin
      FileUtils.cp(path, abs_dest_parent_dir)
    rescue Errno::ENAMETOOLONG
      loginfo("Error: filename #{abs_dest_path} too long, skipping...")
    end

    # Only update the total size transferred if the copy succeeds
    total_bytes_transferred += file_size
  end
  total_bytes_transferred
end



# Initialization block
begin
  # Requires fatattr program on Unix to set Windows file attributes
  if OS.unix?
    abort('Error: missing dependency fatattr') unless `which fatattr`
  end

  # Ask where to copy from
  DEFAULT_SRC_MNT = ARGV[0]
  src_mnt = DEFAULT_SRC_MNT
  loop do
    print "Source mountpoint (#{DEFAULT_SRC_MNT}): "
    input = gets.chomp
    src_mnt = input unless input.empty?

    break if src_mnt && File.directory?(src_mnt)

    warn("Source #{src_mnt} does not exist")
    src_mnt = DEFAULT_SRC_MNT
  end

  # Ask what path to copy to
  dest_root = DEFAULT_DEST_ROOT
  loop do
    print "Location (default: #{DEFAULT_DEST_ROOT}): "
    input = gets.chomp
    dest_root = input unless input.empty?

    break if File.directory?(dest_root)

    warn("Destination #{dest_root} does not exist")
    dest_root = DEFAULT_DEST_ROOT
  end

  # Ask the ticket
  ticket = nil
  loop do
    print 'Ticket number: '
    ticket = gets.chomp

    break if ticket

    warn('Input must not be blank')
    ticket = nil
  end

  # Ask the name
  name = nil
  loop do
    print 'Customer name (last, first): '
    name = gets.chomp

    break if name

    warn 'Input must not be blank'
    name = nil
  end

  dest_dir = File.join(dest_root, "#{ticket}_#{name}")

  # Confirm overwrite if the destination directory exists
  if File.directory?(dest_dir)
    warn "Destination directory #{dest_dir} already exists, continue? (y/N)"
    input = gets.chomp
    abort('Terminating...') if input.downcase != 'y'
  end

  FileUtils.mkpath(dest_dir)

# Normally rescuing the generic Exception class is very bad form, but we need
# to do it to hang with `gets` to keep the window open if the script was run
# from GUI.
rescue Exception => e
  warn "Fatal error: #{e.inspect}"
  gets
  exit 1
end


# Define log stuff
LOGGER = Logger.new(File.join(dest_dir, 'backup.log'))
def loginfo(err)
  warn err
  LOGGER.info err
end
def logfatal(err)
  warn "Fatal error: #{err.inspect}"
  LOGGER.fatal err
  gets
  exit 1
end


# Main backup block
begin
  # We're looking to see if there's a Users folder in the root of src_mnt to
  # determine if the volume is a Windows primary volume, not testing the
  # operating system of the host computer.
  is_windows_volume = File.directory?(File.join(src_mnt, USERS_SRC_FILENAME))
  total_bytes_transferred = if is_windows_volume
                              loginfo('Windows primary partition detected, performing Windows backup...')
                              windows_backup(src_mnt, dest_dir)
                            else
                              loginfo('Windows primary partition not detected, performing basic backup...')
                              basic_backup(src_mnt, dest_dir)
                            end

  mb_transferred = total_bytes_transferred / B_IN_KB / B_IN_KB
  loginfo("Transferred #{mb_transferred}MB(s)")

  # Unhide files and allow the owner to read and write them
  loginfo('Fixing file attributes...')
  if OS.windows?
    `attrib -R -S -H #{dest_dir}"`
  else
    `chmod -R u+rw #{Shellwords.escape(dest_dir)}`
    # `fatattr -r -s -h #{Shellwords.escape(dest_dir)}`
  end

  if OS.unix?
    loginfo('Syncing unwritten data...')
    system('sync')
  end

  loginfo('Backup complete, verify size!')
rescue Exception => e
  logfatal(e)
ensure
  gets # Hang until the user presses enter
end
