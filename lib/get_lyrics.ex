defmodule GetLyrics do
  @moduledoc """
  get lyrics from UtaTen.com
  """

  @doc """
  ## usage
    $ mix deps.get
    $ mix escript.build
    $ ./get_lyrics --title "song title" --artist "song artist" --composer ""song composer"
    $ if exist of lyrics in UtaTen then viewing the lyrics.
  """

  require HTTPoison
  require Floki

  def main(opts) do
    {options, _, _} = OptionParser.parse(opts,
      switches: [title: :string, artist: :string, composer: :string, url: :string],
      aliases:  [t: :title, a: :artist, c: :composer, u: :url]
    )
    # オプションをMapに変換
    options = options |> Enum.into(%{})
    IO.inspect options # 確認

    # urlオプションを持ってたら問答無用でそこから取得
    url = case options |> Map.has_key?(:url) do
      true  -> options[:url]
      false -> options |> getURL
    end

    # urlを取得できなかった場合はnilが返ってくるので
    if url == false do
      IO.puts "Not found"
    else
      # htmlを取得
      %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url)

      # 歌詞サイト全体のhtmlを歌詞 |> 歌詞の部分のみのhtmlに |> 歌詞部分を整形してきれいに
      IO.puts body |> getLyricsBody |> getLyrics
    end
 end

  defp getSongsBody (elem) do
    # 歌詞が見つからなかった場合は、ページに.*見つかりませんでした.*と表示されるので確認
    # 歌詞が見つかったら検索結果の一番上のリンクから歌詞を取得するのでそのURLを取得
    case Regex.match?(~r/[.*][見つかりませんでした][.*]/, elem) do
      true  -> false
      false -> elem
                 |> Floki.parse
                 |> Floki.find(".searchResult__title")
                 |> Floki.find("a")
                 |> Floki.attribute("href")
                 |> Enum.map(&("http://utaten.com" <> &1))
                 |> Enum.at(0)
    end
  end

  # 検索時のURLにタイトルとアーティスト、作曲家を入力しその
  # htmlを取得し返す
  defp getURL(%{title: title, artist: artist, composer: composer}) do
    url = "http://utaten.com/search/=/title=#{title}/artist_name=#{artist}/composer=#{composer}"

    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url)

    body |> getSongsBody
  end

  defp getLyricsBody(elem) do
    # UtaTenの歌詞ページではclass=".medium"以下に歌詞が置かれているのでそれ以下の要素を取得
    # Floki.findは配列で返されるが、今回一つだけだとわかってるのでリストの先頭を抽出
    # Floki.findはそれぞれの要素を{tag_name, class_elem, child_elem}で返すのでgetChildする
    # UtaTenでは歌詞の改行を<br>なのでそれを"\n"に置き換える
    elem
      |> Floki.parse
      |> Floki.find(".medium")
      |> Enum.at(0)
      |> getChild
      |> Enum.map(&(&1 |> br2newline))
  end

  # UtaTenではルビを降っている英語の歌詞ではなぜか文字間のスペースが
  # 文字としては保持されていないので、手動で追加する
  # 文字じゃないならRegexでエラーになるのでガード
  defp putSpace(elem) when is_bitstring(elem) do
    ret = case Regex.match?(~r/^[a-zA-Z0-9!-\/:-@≠\[-`{-~]+$/, elem) do
      true  -> " " <> elem
      false -> elem
    end
    ret
  end

  # それ以外はそのまま
  # これ実行するタイミングでは全部bitstring型になってるような気もするけど一応
  defp putSpace(elem) do elem end

  # Flokiの<br>要素をbitstringの"\n"に置き換え
  defp br2newline(elem) when elem == {"br", [], []} do
      "\n"
  end

  defp br2newline(elem) do elem end

  # Flokiパース後の形が[tag, class, child]なのでその時のchildがほしいときに
  # 実行
  defp getChild(elem) do
    {_, _, child} = elem
    child
  end

  # UtaTenの振られているルビを除去して
  # 実際の歌詞(漢字あるいは英語など)の部分のみを抽出
  # ルビが振られているなら<span class="ruby">以下なのでFlokiでパースすると
  # タプルになっている.なので、タプルでガードしている。
  defp getWithoutRuby(elem) when is_tuple(elem) do
    elem
      |> getChild
      |> Enum.at(0)
      |> getChild
      |> Enum.at(0)
  end

  defp getWithoutRuby(elem) do elem end

  # UtaTenでルビを振っていいないタイプの場合
  # 先頭に余計なものがくっついているのでその後ろを正規表現で抽出
  defp removeHead(elem) when elem != "\n" and is_bitstring(elem) do
    Regex.run(~r/(?:[\n|\r\n]?)(?:\s*)(.*)/, elem) |> Enum.at(1)
  end

  defp removeHead(elem) do elem end

  # ルビが振ってある歌詞かどうか
  defp has_ruby?(elem) when is_tuple(elem) do
    # ルビにはrubyクラスが割り当てられているのでfind
    if elem |> Floki.find(".ruby") == [] do
      false
    else
      true
    end
  end

  defp has_ruby?(elem) do elem end

  # 歌詞を取得
  defp getLyrics(lyrics_html) do
    # UtaTenでルビを含む歌詞なら
    if lyrics_html |> Enum.any?(&(has_ruby?(&1))) do
      # 取得した歌詞要素のルビの部分を削除して元の歌詞のみにする
      # そうすると、ルビを振っている歌詞の場合字間が開かなくて英語だと悲惨なので字間を手動で追加
      # それらを連結
      lyrics_html
        |> Enum.map(&(&1 |> removeHead))
        |> Enum.map(&(&1 |> getWithoutRuby))
        |> Enum.map(&(&1 |> putSpace))
        |> Enum.join("")
    else
      # ルビが振ってない歌詞なら先頭を削除すればきれいになる
      lyrics_html
        |> Enum.map(&(&1 |> removeHead))
        |> Enum.join("")
    end
  end
end

