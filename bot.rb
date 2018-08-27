require 'natto'
require 'twitter'

class Bot
  attr_accessor :client

  public
    def initialize
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key = ENV['CONSUMER_KEY']
        config.consumer_secret = ENV['CONSUMER_SECRET']
        config.access_token = ENV['ACCESS_TOKEN_KEY']
        config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
      end
    end
     
    def tweet(screen_name)
      parser = NattoParser.new
      marcov = Marcov.new

      unparsedBlock = []
      block = []

      tweet = ""
      
      tweets = get_tweet(screen_name, 200)
      words = parser.parseTextArray(tweets)
      
      # 3単語ブロックをツイートごとの配列に格納
      for word in words
        unparsedBlock.push(marcov.genMarcovBlock(word))
      end

      # 3単語ブロックを全て同じ配列へ
      unparsedBlock.each do |a|
        a.each do |v|
          block.push(v)
        end
      end

      # 140字に収まる文章が練成できるまでマルコフ連鎖する
      while tweet.length == 0 or tweet.length > 140 do
        tweetwords = marcov.marcov(block)
        tweet = words2str(tweetwords)
      end

      post(tweet)
    end

    def auto_follow(user_name)
      begin
        @client.follow(get_follower(user_name)- get_friend(user_name))
      rescue Twitter::Error::Forbidden
        # そのまま続ける
      end  
    end
    
  private
    # ===============================================
    # Twitter API
    # ===============================================
    def post(text = "", twitter_id:nil, status_id:nil)
      if status_id
        rep_text = "@#{twitter_id} #{text}"
        @client.update(rep_text, {:in_reply_to_status_id => status_id})
      else
        @client.update(text)
      end
    end
    
    def fav(status_id)
      if status_id
        @client.favorite(status_id)
      end
    end
    
    def retweets(status_id:nil)
      if status_id
        @client.retweet(status_id)
      end
    end
    
    def get_tweet(user_name, tweet_count)
      tweets = []
      
      @client.user_timeline(user_name, {count: tweet_count, exclude: retweets}).each do |timeline|
        tweet = @client.status(timeline.id)
        if not (tweet.text.include?("RT")
          if (tweet.source.include?("TweetDeck") or
              tweet.source.include_("Twitter for Android"))
            tweets.push(tweet2textdata(tweet.text))
        end
      end

      return tweets
    end
    
    def search(word, count)
      tweets = []
      @client.search(word).take(count).each do |tweet|
        tweets.push(tweet.id)
      end
      return tweets
    end
    
    def get_follower(user_name)
      follower = []
      @client.follower_ids(user_name).each do |id|
        follower.push(id)
      end
      return follower
    end
    
    def get_friend(user_name)
      friend = []
      @client.friend_ids(user_name).each do |id|
        friend.push(id)
      end
      return friend
    end

    # ===============================================
    # データ処理メソッド
    # ===============================================
    def tweet2textdata(text)
      replypattern = /@[\w]+/

      text = text.gsub(replypattern, '')

      textURI = URI.extract(text)

      for uri in textURI do
        text = text.gsub(uri, '')
      end 

      return text
    end
end

class NattoParser
  attr_accessor :nm
  
  def initialize()
    @nm = Natto::MeCab.new
  end
  
  def parseTextArray(texts)
    words = []
    index = 0

    for text in texts do
      # 単語数を数える
      count_noun = 0
      @nm.parse(text) do |n|
        count_noun += 1
      end

      # 1単語しかなければ以後の処理を行わない
      if count_noun == 1
        break
      end

      words.push(Array[])
      @nm.parse(text) do |n|
        if n.surface != ""
          words[index].push(n.surface)
        end
      end
      index += 1
    end

    return words
  end
end

class Marcov
  public
    def marcov(array)
      result = []
      block = []

      block = findBlocks(array, nil)
      begin
        result = connectBlocks(block, result)
        if result == nil
          raise RunTimeError
        end
      rescue RuntimeError
        retry
      end
     
      # resultの最後の単語がnilになるまで繰り返す
      while result[result.length-1] != nil do
        block = findBlocks(array, result[result.length-1])
        begin
          result = connectBlocks(block, result)
          if result == nil
            raise RuntimeError
          end
        rescue RuntimeError
          retry
        end
      end
      
      return result
    end

    def genMarcovBlock(words)
      array = []

      # 最初と最後はnilにする
      words.unshift(nil)
      words.push(nil)

      # 3単語ずつ配列に格納
      for i in 0..words.length-3
        array.push([words[i], words[i+1], words[i+2]])
      end

      return array
    end

  private
    def findBlocks(array, target)
      blocks = []
      for block in array
        if block[0] == target
          blocks.push(block)
        end
      end
      
      return blocks
    end

    def connectBlocks(array, dist)
      i = 0
      begin
        for word in array[rand(array.length)]
          if i != 0
            dist.push(word)
          end
          i += 1
        end
      rescue NoMethodError
        return nil
      else
        return dist
      end
    end
end

# ===================================================
# 汎用関数
# ===================================================
def words2str(words)
  str = ""
  for word in words do
    if word != nil
      str += word
    end
  end
  return str
end

# ===================================================
# MAIN
# ===================================================
def main()
  bot = Bot.new

  bot.tweet("hsm_hx")
  bot.auto_follow("hsm_ai")
end

main()
