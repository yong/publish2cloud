require 'hmac-sha1' # on OS X: sudo gem install ruby-hmac
require 'net/https'
require 'base64'

module Publish2Cloud 
	class Publisher

		def initialize s3_access, s3_secret, s3_bucket, cf_distribution
		  @s3_access = s3_access
		  @s3_secret = s3_secret
		  @s3_bucket = s3_bucket
		  @cf_distribution = cf_distribution
		end

		#http://aws.amazon.com/cloudfront/faqs/#How_long_will_Amazon_CloudFront_keep_my_files
		#headers looks like this:
		#{'Cache-Control' => public, max-age=86400', 'Content-Type' => 'text/html; charset=utf-8'}
		#{'Cache-Control' => 'max-age=0, private, must-revalidate', 'Content-Type' => 'text/html; charset=utf-8'}
		def fetch_and_upload_to_s3 url, s3_key, headers = {'Content-Type' => 'text/html; charset=utf-8'}
		  puts url
		
			res = Net::HTTP.get_response URI.parse(url)

		  raise res.code if res.code != '200'
		  #puts res.body

		  s3= RightAws::S3.new(@s3_access, @s3_secrets)
		  bucket = s3.bucket(@s3_bucket)
		  bucket.put(s3key, res.body, {}, 'public-read', headers)
		  
		  puts "http://#{@s3_bucket}.s3.amazonaws.com/#{s3key}"
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

			puts req.body

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			res = http.request(req)

			# TODO: Check status code and pretty print the output
			# Tip: pipe the output to | xmllint -format - |less for easier reading
			#puts $STDERR res.code
			puts res.body
			return 0
		end
		
		def set_root
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
				'Authorization' => "AWS %s:%s" % [s3_access, Base64.encode64(digest.digest)],
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
	end
end
