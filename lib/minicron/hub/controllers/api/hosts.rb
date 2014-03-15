require 'net/ssh'
require 'etc'

class Minicron::Hub::App
  # Get all hosts that a job
  # TODO: Add offset/limit
  get '/api/hosts' do
    content_type :json
    hosts = Minicron::Hub::Host.all.includes(:jobs).order(:id => :asc)
    HostSerializer.new(hosts).serialize.to_json
  end

  # Get a single host by its ID
  get '/api/hosts/:id' do
    content_type :json
    host = Minicron::Hub::Host.includes(:jobs).find(params[:id])
    HostSerializer.new(host).serialize.to_json
  end

  # Create a new host
  post '/api/hosts' do
    content_type :json
    begin
      # Load the JSON body
      request_body = Oj.load(request.body)

      # Try and save the new host
      host = Minicron::Hub::Host.create(
        :name => request_body['host']['name'],
        :hostname => request_body['host']['hostname']
      )

      # Return the new host
      HostSerializer.new(host).serialize.to_json
    # TODO: nicer error handling here with proper validation before hand
    rescue Exception => e
      { :error => e.message }.to_json
    end
  end

  # Update an existing host
  put '/api/hosts/:id' do
    content_type :json
    begin
      # Load the JSON body
      request_body = Oj.load(request.body)

      # Try and save the updated host
      host = Minicron::Hub::Host.find(params[:id])
      host.name = request_body['host']['name']
      host.fqdn = request_body['host']['fqdn']
      host.ip = request_body['host']['ip']
      host.public_key = request_body['host']['public_key']
      host.save!

      # Return the new host
      HostSerializer.new(host).serialize.to_json
    # TODO: nicer error handling here with proper validation before hand
    rescue Exception => e
      { :error => e.message }.to_json
    end
  end

  # Delete an existing host
  delete '/api/hosts/:id' do
    content_type :json
    begin
      # Try and delete the host
      Minicron::Hub::Host.destroy(params[:id])

      # This is what ember expects as the response
      status 204
    # TODO: nicer error handling here with proper validation before hand
    rescue Exception => e
      { :error => e.message }.to_json
    end
  end

  # Used to test an SSH connection for a host
  get '/api/hosts/:id/test_ssh' do
    begin
      # Get the host
      host = Minicron::Hub::Host.find(params[:id])

      # Set the location of the private key we are going to use
      private_key_path = File.expand_path("~/.ssh/minicron_host_#{host.id}_rsa")

      # Set up the ssh connection options
      options = {
        :auth_methods => ['publickey'],
        :host_key => 'ssh-rsa',
        :keys => [private_key_path],
        :timeout => 10
      }

      # Connect to the host
      ssh = Net::SSH.start(host.ip, Etc.getlogin, options)

      # Try and run a command
      test = ssh.exec!('echo 1').strip

      # Did we get back what we expect?
      if test == '1'
        { :success => true }.to_json
      else
        fail Exception, "Test command failed. '1' expected, recieved: #{test}"
      end
    rescue Exception => e
      { :success => false, :error => e.message }.to_json
    end
  end
end