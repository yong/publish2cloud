require 'hmac-sha1' # on OS X: sudo gem install ruby-hmac
require 'net/https'
require 'net/http'
require 'uri'
require 'base64'
require 'right_aws'

module Publish2Cloud
 
	class Publisher

		def initialize s3_access, s3_secret, s3_bucket, cf_distribution, max_age = nil
		  @s3_access = s3_access
		  @s3_secret = s3_secret
		  @s3_bucket = s3_bucket
		  @cf_distribution = cf_distribution
		  @max_age = max_age
		end
		
		def run urls
		  ensure_s3_bucket_exist
		  set_root 'index.html'
		  
		  urls.each {|x|
		    uri = URI.parse(x)
		    if uri.path == "" or uri.path == "/"
		      s3_key = "index.html"
		    else
		      s3_key = uri.path[1..-1]
		    end
		    puts "#{x} -> #{s3_key}"
		    fetch_and_upload_to_s3 x, s3_key
		    invalidate [s3_key]
		  }
		end

		#http://aws.amazon.com/cloudfront/faqs/#How_long_will_Amazon_CloudFront_keep_my_files
		#headers looks like this:
		#{'Cache-Control' => public, max-age=86400', 'Content-Type' => 'text/html; charset=utf-8'}
		#{'Cache-Control' => 'max-age=0, private, must-revalidate', 'Content-Type' => 'text/html; charset=utf-8'}
		def fetch_and_upload_to_s3 url, s3_key
		  res = Net::HTTP.get_response URI.parse(url)

		  raise res.code if res.code != '200'
		  #puts res.body

		  s3= RightAws::S3.new(@s3_access, @s3_secret, {:logger => Logger.new('log/publish2cloud.log')})
		  bucket = s3.bucket(@s3_bucket)
		  if @max_age
		    headers = {'Cache-Control' => "public, max-age=#{@max_age}", 'Content-Type' => 'text/html; charset=utf-8'}
		  else
		    headers = {'Content-Type' => 'text/html; charset=utf-8'}
		  end
		  bucket.put(s3_key, res.body, {}, 'public-read', headers)
		  
		  puts "Uploaded #{s3_key}"
		end

		def invalidate paths_as_array
		  paths = nil
		  
		  if paths_as_array.length > 0
				paths = '<Path>/' + paths_as_array.join('</Path><Path>/') + '</Path>'
			end

			date = Time.now.utc
			date = date.strftime("%a, %d %b %Y %H:%M:%S %Z")
			digest = HMAC::SHA1.new(@s3_secret)
			digest << date

			uri = URI.parse('https://cloudfront.amazonaws.com/2010-08-01/distribution/' + @cf_distribution + '/invalidation')

			if paths != nil
				req = Net::HTTP::Post.new(uri.path)
			else
				req = Net::HTTP::Get.new(uri.path)
			end

			req.initialize_http_header({
				'x-amz-date' => date,
				'Content-Type' => 'text/xml',
				'Authorization' => "AWS %s:%s" % [@s3_access, Base64.encode64(digest.digest)]
			})

			if paths != nil
				req.body = "<InvalidationBatch>" + paths + "<CallerReference>ref_#{Time.now.utc.to_i}</CallerReference></InvalidationBatch>"
			end

			#puts req.body

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			res = http.request(req)

			# TODO: Check status code and pretty print the output
			# Tip: pipe the output to | xmllint -format - |less for easier reading
			#puts $STDERR res.code
			#puts res.body
			puts "Invalidated #{paths_as_array}"
			return 0
		end
		
		def set_root newobj
			date = Time.now.utc
			date = date.strftime("%a, %d %b %Y %H:%M:%S %Z")
			digest = HMAC::SHA1.new(@s3_secret)
			digest << date

			uri = URI.parse('https://cloudfront.amazonaws.com/2010-08-01/distribution/' + @cf_distribution + '/config')

			req = Net::HTTP::Get.new(uri.path)

			req.initialize_http_header({
				'x-amz-date' => date,
				'Content-Type' => 'text/xml',
				'Authorization' => "AWS %s:%s" % [@s3_access, Base64.encode64(digest.digest)]
			})

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			res = http.request(req)
			puts res
			match = /<DefaultRootObject>(.*?)<\/DefaultRootObject>/.match(res.body)
			currentobj = match ? match[1] : nil

			if newobj == currentobj
				puts "'#{currentobj}' is already the DefaultRootObject"
				return -1
			end

			etag = res.header['etag']

			req = Net::HTTP::Put.new(uri.path)

			req.initialize_http_header({
				'x-amz-date' => date,
				'Content-Type' => 'text/xml',
				'Authorization' => "AWS %s:%s" % [@s3_access, Base64.encode64(digest.digest)],
				'If-Match' => etag
			})

			if currentobj == nil
				regex = /<\/DistributionConfig>/
				replace = "<DefaultRootObject>#{newobj}</DefaultRootObject></DistributionConfig>"
			else
				regex = /<DefaultRootObject>(.*?)<\/DefaultRootObject>/
				replace = "<DefaultRootObject>#{newobj}</DefaultRootObject>"
			end

			req.body = res.body.gsub(regex, replace)

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			res = http.request(req)

			puts res.code
			puts res.body
			return 0
		end
		
		def ensure_s3_bucket_exist
		  s3= RightAws::S3.new(@s3_access, @s3_secret, {:logger => Logger.new('log/publish2cloud.log')})
		  bucket = s3.bucket(@s3_bucket)
		  begin
		    bucket.keys
		    puts "Bucket '#{@s3_bucket}' exists"
		  rescue
		    puts "Going to creat '#{@s3_bucket}'"
		    RightAws::S3::Bucket.create(s3, @s3_bucket, true, 'public-read')
		  end
		end
		
	end
end
