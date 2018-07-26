require 'spec_helper'
require 'cloudinary'
require 'action_view'
require 'cloudinary/helper'

BREAKPOINTS = [100, 200, 300, 399]
COMMON_TRANS = {
    effect: 'sepia',
    cloud_name: 'test123',
    client_hints: false
}
COMMON_TRANSFORMATION_STR = 'e_sepia'

def expected_srcset(public_id, path, common_trans, breakpoints)
  breakpoints.map {|width| "#{path}/#{common_trans}/c_scale,w_#{width}/#{public_id} #{width}w"}.join(', ')
end

describe 'Responsive breakpoints' do
  before :all do
    # Test the helper in the context it runs in in production
    ActionView::Base.send :include, CloudinaryHelper

  end

  let(:cloud_name) {COMMON_TRANS[:cloud_name]}
  let(:root_path) {"http://res.cloudinary.com/#{cloud_name}"}
  let(:upload_path) {"#{root_path}/image/upload"}

  let(:options) {COMMON_TRANS}
  # let(:helper) {helper_class.new}
  let(:helper) {
    ActionView::Base.new
  }
  let(:test_tag) {TestTag.new(helper.cl_image_tag('sample.jpg', options))}
  describe 'srcset' do
    it 'Should create srcset attribute with provided breakpoints' do
      options[:srcset] = {:breakpoints => BREAKPOINTS}
      srcset = test_tag['srcset'].split(", ")
      expect(srcset.length).to eq(4)
      expected_tag = expected_srcset('sample.jpg', upload_path, COMMON_TRANSFORMATION_STR, BREAKPOINTS)
      expect(test_tag['srcset']).to match(expected_tag)
    end
    it "Support srcset attribute defined by min width max width and max images" do
      options[:srcset] = {:min_width => BREAKPOINTS.first,
                          :max_width => BREAKPOINTS.last,
                          :max_images => BREAKPOINTS.length}

      expected_tag = expected_srcset('sample.jpg', upload_path, COMMON_TRANSFORMATION_STR, BREAKPOINTS)
      expect(test_tag['srcset']).to match(expected_tag)
    end
    it "should generate a single srcset image" do
      options[:srcset] = {:min_width => BREAKPOINTS.first,
                          :max_width => BREAKPOINTS.last,
                          :max_images => 1}

      expected_tag = expected_srcset('sample.jpg', upload_path, COMMON_TRANSFORMATION_STR, [BREAKPOINTS.last])
      expect(test_tag['srcset']).to match(expected_tag)
    end
    it "Should support custom transformation for srcset items" do
      options[:srcset] = {
          :breakpoints => BREAKPOINTS,
          :transformation => {:crop => 'crop', :width => 10, :height => 20}
      }

      expected_tag = expected_srcset('sample.jpg', upload_path, 'c_crop,h_20,w_10', BREAKPOINTS)
      expect(test_tag['srcset']).to match(expected_tag)
    end
    it "Should populate sizes attribute" do
      options[:srcset] = {
          :breakpoints => BREAKPOINTS,
          :sizes => true
      }
      expected_sizes_attr = '(max-width: 100px) 100px, (max-width: 200px) 200px, ' +
          '(max-width: 300px) 300px, (max-width: 399px) 399px'
      expect(test_tag['sizes']).to match(expected_sizes_attr)
    end
    it "Should support srcset string value" do
      raw_src_set = "some srcset data as is"
      options[:srcset] = raw_src_set

      expect(test_tag['srcset']).to match(raw_src_set)
    end
    it "Should remove width and height attributes in case srcset is specified, but passed to transformation" do
      options.merge!({
                         :srcset => {
                             :breakpoints => BREAKPOINTS,
                         },
                         :width => 500,
                         :height => 500,
                         :crop => 'scale'

                     })

      expected_tag = expected_srcset('sample.jpg', upload_path, 'c_scale,e_sepia,h_500,w_500', BREAKPOINTS)
      expect(test_tag['srcset']).to match(expected_tag)
      expect(test_tag['width']).to be_nil
    end

  end

  describe 'cl_picture_tag' do
    let (:options) {{
        :cloud_name => 'test123',
        :width => BREAKPOINTS.last,
        :height => BREAKPOINTS.last,
        :crop => :fill}}
    let (:fill_trans_str) {Cloudinary::Utils.generate_transformation_string(options)}
    let (:sources) {
        [
            {
                :min_width => BREAKPOINTS.third,
                :transformation => {:effect => "sepia", :angle => 17, :width => BREAKPOINTS.last, :crop => :scale}
            },
            {
                :min_width => BREAKPOINTS.second,
                :transformation => {:effect => "colorize", :angle => 18, :width => BREAKPOINTS.second, :crop => :scale}
            },
            {
                :min_width => BREAKPOINTS.first,
                :transformation => {:effect => "blur", :angle => 19, :width => BREAKPOINTS.first, :crop => :scale}
            }
        ]
    }
    let(:test_tag) {TestTag.new(helper.cl_picture_tag('sample.jpg', options, sources))}
    def source_url(t)
      t = Cloudinary::Utils.generate_transformation_string(t)
      upload_path + '/' + fill_trans_str + '/' + t + "/sample.jpg"
    end
    it "should create a picture tag" do
      expect(test_tag[:attributes]).to be_nil
      expect(test_tag.children.length).to be(4)
      sources.each_with_index do |source,i|
        expect(test_tag.children[i][:srcset]).to eq(  source_url(source[:transformation]))
      end

      [
          "(min_width: #{BREAKPOINTS.third}px)",
          "(min_width: #{BREAKPOINTS.second}px)",
          "(min_width: #{BREAKPOINTS.first}px)",
      ].each_with_index do |expected, i|
        expect(test_tag.children[i][:media]).to eq(expected)
      end

    end
  end

end