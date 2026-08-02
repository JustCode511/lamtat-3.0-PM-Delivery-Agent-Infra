# ── Frontend: private S3 + CloudFront (free HTTPS) ───────────
# CloudFront serves the SPA over HTTPS (free *.cloudfront.net cert) and routes
# /api/* to the API Gateway — same-origin, so no CORS and no frontend changes.
# The S3 bucket is PRIVATE; only CloudFront can read it (via Origin Access Control).

# Managed policies (free) controlling caching behavior
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name != "" ? var.frontend_bucket_name : "${var.project_name}-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # so `terraform destroy` clears objects too
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Strip the /api prefix before forwarding to API Gateway (/api/health -> /health)
resource "aws_cloudfront_function" "strip_api" {
  name    = "${var.project_name}-${var.environment}-strip-api"
  runtime = "cloudfront-js-2.0"
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri === '/api' || uri === '/api/') {
        request.uri = '/';
      } else if (uri.startsWith('/api/')) {
        request.uri = uri.substring(4);
      }
      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  comment             = "${var.project_name}-${var.environment} frontend"

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    origin_id   = "api"
    domain_name = replace(aws_apigatewayv2_api.http.api_endpoint, "https://", "")
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static site from S3
  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # /api/* -> API Gateway (no caching, forward everything, strip /api)
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "api"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.strip_api.arn
    }
  }

  # SPA routing: serve index.html for unknown paths so React Router works
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # free HTTPS on *.cloudfront.net
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn } }
    }]
  })
}
