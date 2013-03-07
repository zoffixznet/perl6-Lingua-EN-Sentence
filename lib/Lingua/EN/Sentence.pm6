module Lingua::EN::Sentence:auth<LlamaRider>;
use v6;

my Str $EOS="\001";
token AP { [<[\'\"»\)\]\}]>]? } ## AFTER PUNCTUATION
token PAP { [<punct> AP]? };
token alphad { <.alpha>|'-' }

my @PEOPLE = <jr mr mrs ms dr prof sr sens? reps? gov attys? supt det rev>;
my @ARMY = <col gen lt cmdr adm capt sgt cpl maj>;
my @INSTITUTES = <dept univ assn bros>;
my @COMPANIES = <inc ltd co corp>;
my @PLACES = <arc al ave blv?d cl ct cres dr expy? dist mt ft fw?y
 hwa?y la pde? pl plz rd st tce Ala Ariz Ark Cal Calif Col Colo Conn
 Del Fed Fla Ga Ida Id Ill Ind Ia Kan Kans Ken Ky La Me Md Is Mass 
 Mich Minn Miss Mo Mont Neb Nebr Nev Mex Okla Ok Ore Penna Penn Pa
 Dak Tenn Tex Ut Vt Va Wash Wis Wisc Wy Wyo USAFA Alta Man Ont Qué
 Sask Yuk>;
my @MONTHS = <jan feb mar apr may jun jul aug sep oct nov dec sept>;
my @MISC = <vs etc no esp>;

my Str @ABBREVIATIONS = (@PEOPLE, @ARMY, @INSTITUTES, @COMPANIES, @PLACES, @MONTHS, @MISC );

sub add_acronyms(*@new_acronyms) is export {
  push @ABBREVIATIONS, @new_acronyms; }
sub get_acronyms() is export {return @ABBREVIATIONS;}
sub set_acronyms(*@new_acronyms) is export {@ABBREVIATIONS=@new_acronyms;}
sub get_EOS() is export {return $EOS;}
sub set_EOS(Str $end_marker) is export {$EOS=$end_marker;}

#------------------------------------------------------------------------------
# get_sentences - takes text input and splits it into sentences.
# A regular expression cuts viciously the text into sentences, 
# and then a list of rules (some of them consist of a list of abbreviations)
# is applied on the marked text in order to fix end-of-sentence markings on 
# places which are not indeed end-of-sentence.
#------------------------------------------------------------------------------
sub get_sentences(Str $text) is export {
  my @sentences;
  if ($text.defined) {
    my $marked_text = first_sentence_breaking($text);
    my $fixed_marked_text = remove_false_end_of_sentence($marked_text);
    $fixed_marked_text = split_unsplit_stuff($fixed_marked_text);
    @sentences = split(/$EOS/,$fixed_marked_text).map(clean_sentences($_));
  }
  return @sentences;
}


#==============================================================================
#
# Private methods
#
#==============================================================================

## Please email me any suggestions for optimizing these RegExps.
sub remove_false_end_of_sentence(Str $s) {
##	## don't do u.s.a.
  $s ~~ s:g/(<-alphad><.alpha><.PAP>\s)$EOS/, $1);
  $s ~~ s:g/(<-alphad><.alpha><.punct>)$EOS/$1/;
  # don't split after a white-space followed by a single letter followed
  # by a dot followed by another whitespace.
  $s ~~ s:g/(<.space><.alpha>'.'<.space>+)$EOS/$1/;

  # fix: bla bla... yada yada
  $s ~~ s:g/'...' $EOS <lower>/...$<lower>/;
  # fix "." "?" "!"
  $s ~~ s:g/(['"]<.punct>['"]\s+)$EOS/$1/;
  ## fix where abbreviations exist
  foreach (@ABBREVIATIONS) { $s ~~ s:g:i/(\b$_<.PAP>\s)$EOS/$1/; }
	
  # don't break after quote unless its a capital letter.
  $s ~~ s:g/(["']\s*)$EOS(\s*[[:lower:]])/$1$2/;

  # don't break: text . . some more text.
  $s ~~ s:g/(\s\.\s)$EOS(\s*)/$1$2/;

  $s ~~ s:g/(\s<.PAP>\s)$EOS/$1/;

  return $s;
}

# TODO:
sub split_unsplit_stuff(Str $text) {
  $text ~~ s:g/(\D\d+)(<.punct>)(\s+)/$1$2$EOS$3/;
  $text ~~ s:g/(<.PAP>\s)(\s*\()/$1$EOS$2/;
  $text ~~ s:g/('\w<.punct>)(\s)/$1$EOS$2/;
  $text ~~ s:g:i/(\sno\.)(\s+)(?!\d)/$1$EOS$2/;
  ##	# split where single capital letter followed by dot makes sense to break.
  ##	# notice these are exceptions to the general rule NOT to split on single
  ##	# letter.
  ##	# notice also that sibgle letter M is missing here due to French 'mister'
  ##	# which is representes as M.
  ##	#
  ##	# the rule will not split on names begining or containing 
  ##	# single capital letter dot in the first or second name
  ##	# assuming 2 or three word name.
  ##	$text=~s/(\s[[:lower:]]\w+\s+[^[[:^upper:]M]\.)(?!\s+[[:upper:]]\.)/$1$EOS/sg;
  
  # add EOS when you see "a.m." or "p.m." followed by a capital letter.
  $text ~~ s:g/([ap]\.m\.\s+)([[:upper:]])/$1$EOS$2/;
  
  return $text;
}

sub clean_sentences(@sentences) {
  return @sentences.grep({.defined and .match(/<.alpha>/)}).map:{.trim };
}

#TODO
sub first_sentence_breaking(Str $text) {
  $text ~~ s:g/\n\s*\n/$EOS/;	## double new-line means a different sentence.
  $text ~~ s:g/(<.PAP>\s)/$1$EOS/;
  $text ~~ s:g/(\s<.alpha><.punct>)/$1$EOS/; # breake also when single letter comes before punc.
  return $text;
}

=begin pod

=head1 NAME

Lingua::EN::Sentence - Module for splitting text into sentences.

=head1 SYNOPSIS

	use Lingua::EN::Sentence;
	add_acronyms('lt','gen');		## adding support for 'Lt. Gen.'
	my $sentences=get_sentences($text);	## Get the sentences.
	foreach my $sentence (@$sentences) {
		## do something with $sentence
	}

=head1 DESCRIPTION

The C<Lingua::EN::Sentence> module contains the function get_sentences, which splits text into its constituent sentences, based on a regular expression and a list of abbreviations (built in and given).

Certain well know exceptions, such as abreviations, may cause incorrect segmentations.  But some of them are already integrated into this code and are being taken care of.  Still, if you see that there are words causing the get_sentences() to fail, you can add those to the module, so it notices them.

=head1 ALGORITHM

Basically, I use a 'brute' regular expression to split the text into sentences.  (Well, nothing is yet split - I just mark the end-of-sentence).  Then I look into a set of rules which decide when an end-of-sentence is justified and when it's a mistake. In case of a mistake, the end-of-sentence mark is removed. 

What are such mistakes? Cases of abbreviations, for example. I have a list of such abbreviations (Please see `Acronym/Abbreviations list' section), and more general rules (for example, the abbreviations 'i.e.' and '.e.g.' need not to be in the list as a special rule takes care of all single letter abbreviations).

=head1 FUNCTIONS

All functions used should be requested in the 'use' clause. None is exported by default.

=head2 get_sentences( $text )

The get sentences function takes a scalar containing ascii text as an argument and returns a reference to an array of sentences that the text has been split into.
Returned sentences will be trimmed (beginning and end of sentence) of white-spaces.
Strings with no alpha-numeric characters in them, won't be returned as sentences.

=head2 add_acronyms( @acronyms )

This function is used for adding acronyms not supported by this code.  Please see `Acronym/Abbreviations list' section for the abbreviations already supported by this module.

=head2 get_acronyms(	)

This function will return the defined list of acronyms.

=head2 set_acronyms( @my_acronyms )

This function replaces the predefined acroym list with the given list.

=head2 get_EOS(	)

This function returns the value of the string used to mark the end of sentence. You might want to see what it is, and to make sure your text doesn't contain it. You can use set_EOS() to alter the end-of-sentence string to whatever you desire.

=head2 set_EOS( $new_EOS_string )

This function alters the end-of-sentence string used to mark the end of sentences. 

=head2 set_locale( $new_locale )
Revceives language locale in the form language.country.character-set
for example:
	"fr_CA.ISO8859-1"
for Canadian French using character set ISO8859-1.

Returns a reference to a hash containing the current locale formatting values.
Returns undef if got undef.


The following will set the LC_COLLATE behaviour to Argentinian Spanish. NOTE: The naming and avail­ ability of locales depends on your operating sys­ tem. Please consult the perllocale manpage for how to find out which locales are available in your system.

$loc = set_locale( "es_AR.ISO8859-1" );

This actually does this:

$loc = setlocale( LC_ALL, "es_AR.ISO8859-1" );

=head1 Acronym/Abbreviations list

You can use the get_acronyms() function to get acronyms.
It has become too long to specify in the documentation.

If I come across a good general-purpose list - I'll incorporate it into this module.
Feel free to suggest such lists. 

=head1 FUTURE WORK
[1] Object Oriented like usage
[2] Supporting more than just English/French
[3] Code optimization. Currently everything is RE based and not so optimized RE
[4] Possibly use more semantic heuristics for detecting a beginning of a sentence

=head1 SEE ALSO

	Text::Sentence

=head1 AUTHOR

Deyan Ginev, 2013.

Perl5 CPAN author:
 Shlomo Yona (shlomo@cs.haifa.ac.il)

Released under the same terms as Perl 6; see the LICENSE file for details.

=end pod