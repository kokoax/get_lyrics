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
    # $B%*%W%7%g%s$r(BMap$B$KJQ49(B
    options = options |> Enum.into(%{})
    IO.inspect options # $B3NG'(B

    # url$B%*%W%7%g%s$r;}$C$F$?$iLdEzL5MQ$G$=$3$+$i<hF@(B
    url = case options |> Map.has_key?(:url) do
      true  -> options[:url]
      false -> options |> getURL
    end

    # url$B$r<hF@$G$-$J$+$C$?>l9g$O(Bnil$B$,JV$C$F$/$k$N$G(B
    if url == false do
      IO.puts "Not found"
    else
      # html$B$r<hF@(B
      %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url)

      # $B2N;l%5%$%HA4BN$N(Bhtml$B$r2N;l(B |> $B2N;l$NItJ,$N$_$N(Bhtml$B$K(B |> $B2N;lItJ,$r@07A$7$F$-$l$$$K(B
      IO.puts body |> getLyricsBody |> getLyrics
    end
 end

  defp getSongsBody (elem) do
    # $B2N;l$,8+$D$+$i$J$+$C$?>l9g$O!"%Z!<%8$K(B.*$B8+$D$+$j$^$;$s$G$7$?(B.*$B$HI=<($5$l$k$N$G3NG'(B
    # $B2N;l$,8+$D$+$C$?$i8!:w7k2L$N0lHV>e$N%j%s%/$+$i2N;l$r<hF@$9$k$N$G$=$N(BURL$B$r<hF@(B
    case Regex.match?(~r/[.*][$B8+$D$+$j$^$;$s$G$7$?(B][.*]/, elem) do
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

  # $B8!:w;~$N(BURL$B$K%?%$%H%k$H%"!<%F%#%9%H!":n6J2H$rF~NO$7$=$N(B
  # html$B$r<hF@$7JV$9(B
  defp getURL(%{title: title, artist: artist, composer: composer}) do
    url = "http://utaten.com/search/=/title=#{title}/artist_name=#{artist}/composer=#{composer}"

    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url)

    body |> getSongsBody
  end

  defp getLyricsBody(elem) do
    # UtaTen$B$N2N;l%Z!<%8$G$O(Bclass=".medium"$B0J2<$K2N;l$,CV$+$l$F$$$k$N$G$=$l0J2<$NMWAG$r<hF@(B
    # Floki.find$B$OG[Ns$GJV$5$l$k$,!":#2s0l$D$@$1$@$H$o$+$C$F$k$N$G%j%9%H$N@hF,$rCj=P(B
    # Floki.find$B$O$=$l$>$l$NMWAG$r(B{tag_name, class_elem, child_elem}$B$GJV$9$N$G(BgetChild$B$9$k(B
    # UtaTen$B$G$O2N;l$N2~9T$r(B<br>$B$J$N$G$=$l$r(B"\n"$B$KCV$-49$($k(B
    elem
      |> Floki.parse
      |> Floki.find(".medium")
      |> Enum.at(0)
      |> getChild
      |> Enum.map(&(&1 |> br2newline))
  end

  # UtaTen$B$G$O%k%S$r9_$C$F$$$k1Q8l$N2N;l$G$O$J$<$+J8;z4V$N%9%Z!<%9$,(B
  # $BJ8;z$H$7$F$OJ];}$5$l$F$$$J$$$N$G!"<jF0$GDI2C$9$k(B
  # $BJ8;z$8$c$J$$$J$i(BRegex$B$G%(%i!<$K$J$k$N$G%,!<%I(B
  defp putSpace(elem) when is_bitstring(elem) do
    ret = case Regex.match?(~r/^[a-zA-Z0-9!-\/:-@$B!b(B\[-`{-~]+$/, elem) do
      true  -> " " <> elem
      false -> elem
    end
    ret
  end

  # $B$=$l0J30$O$=$N$^$^(B
  # $B$3$l<B9T$9$k%?%$%_%s%0$G$OA4It(Bbitstring$B7?$K$J$C$F$k$h$&$J5$$b$9$k$1$I0l1~(B
  defp putSpace(elem) do elem end

  # Floki$B$N(B<br>$BMWAG$r(Bbitstring$B$N(B"\n"$B$KCV$-49$((B
  defp br2newline(elem) when elem == {"br", [], []} do
      "\n"
  end

  defp br2newline(elem) do elem end

  # Floki$B%Q!<%98e$N7A$,(B[tag, class, child]$B$J$N$G$=$N;~$N(Bchild$B$,$[$7$$$H$-$K(B
  # $B<B9T(B
  defp getChild(elem) do
    {_, _, child} = elem
    child
  end

  # UtaTen$B$N?6$i$l$F$$$k%k%S$r=|5n$7$F(B
  # $B<B:]$N2N;l(B($B4A;z$"$k$$$O1Q8l$J$I(B)$B$NItJ,$N$_$rCj=P(B
  # $B%k%S$,?6$i$l$F$$$k$J$i(B<span class="ruby">$B0J2<$J$N$G(BFloki$B$G%Q!<%9$9$k$H(B
  # $B%?%W%k$K$J$C$F$$$k(B.$B$J$N$G!"%?%W%k$G%,!<%I$7$F$$$k!#(B
  defp getWithoutRuby(elem) when is_tuple(elem) do
    elem
      |> getChild
      |> Enum.at(0)
      |> getChild
      |> Enum.at(0)
  end

  defp getWithoutRuby(elem) do elem end

  # UtaTen$B$G%k%S$r?6$C$F$$$$$J$$%?%$%W$N>l9g(B
  # $B@hF,$KM>7W$J$b$N$,$/$C$D$$$F$$$k$N$G$=$N8e$m$r@55,I=8=$GCj=P(B
  defp removeHead(elem) when elem != "\n" and is_bitstring(elem) do
    Regex.run(~r/(?:[\n|\r\n]?)(?:\s*)(.*)/, elem) |> Enum.at(1)
  end

  defp removeHead(elem) do elem end

  # $B%k%S$,?6$C$F$"$k2N;l$+$I$&$+(B
  defp has_ruby?(elem) when is_tuple(elem) do
    # $B%k%S$K$O(Bruby$B%/%i%9$,3d$jEv$F$i$l$F$$$k$N$G(Bfind
    if elem |> Floki.find(".ruby") == [] do
      false
    else
      true
    end
  end

  defp has_ruby?(elem) do elem end

  # $B2N;l$r<hF@(B
  defp getLyrics(lyrics_html) do
    # UtaTen$B$G%k%S$r4^$`2N;l$J$i(B
    if lyrics_html |> Enum.any?(&(has_ruby?(&1))) do
      # $B<hF@$7$?2N;lMWAG$N%k%S$NItJ,$r:o=|$7$F85$N2N;l$N$_$K$9$k(B
      # $B$=$&$9$k$H!"%k%S$r?6$C$F$$$k2N;l$N>l9g;z4V$,3+$+$J$/$F1Q8l$@$HHa;4$J$N$G;z4V$r<jF0$GDI2C(B
      # $B$=$l$i$rO"7k(B
      lyrics_html
        |> Enum.map(&(&1 |> removeHead))
        |> Enum.map(&(&1 |> getWithoutRuby))
        |> Enum.map(&(&1 |> putSpace))
        |> Enum.join("")
    else
      # $B%k%S$,?6$C$F$J$$2N;l$J$i@hF,$r:o=|$9$l$P$-$l$$$K$J$k(B
      lyrics_html
        |> Enum.map(&(&1 |> removeHead))
        |> Enum.join("")
    end
  end
end

