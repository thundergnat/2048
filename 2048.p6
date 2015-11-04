use Term::termios;

constant $saved   = Term::termios.new(fd => 1).getattr;
constant $termios = Term::termios.new(fd => 1).getattr;
# raw mode interferes with carriage returns, so
# set flags needed to emulate it manually
$termios.unset_iflags(<BRKINT ICRNL ISTRIP IXON>);
$termios.unset_lflags(<ECHO ICANON IEXTEN ISIG>);
$termios.setattr(:DRAIN);

# reset terminal to original setting on exit
END { $saved.setattr(:NOW) }

my @board = ( ['', '', '', ''] xx 4 );
my $save  = '';
my $score = 0;
constant $cell  = 6; # width
constant $tab   = "\t\t"; # spacing from left edge
constant $top   = join '─' x $cell, '┌', '┬' xx 3, '┐';
constant $mid   = join '─' x $cell, '├', '┼' xx 3, '┤';
constant $bot   = join '─' x $cell, '└', '┴' xx 3, '┘';

my %dir = (
   (27, 91, 65) => 'up',
   (27, 91, 66) => 'down',
   (27, 91, 67) => 'right',
   (27, 91, 68) => 'left',
);

sub row (@row) {
    sprintf("│%{$cell}s│%{$cell}s│%{$cell}s│%{$cell}s│\n", @row».&center )
}

sub center ($s){
    my $c   = $cell - $s.chars;
    my $pad = ' ' x ceiling($c/2);
    sprintf "%{$cell}s", "$s$pad";
}

sub draw-board {
    run('clear');
    print "\n\n{$tab}Press direction arrows to move.";
    print "\n\n{$tab}Press q to quit.\n\n$tab$top\n$tab";
    print join "$tab$mid\n$tab", map { $_.&row }, @board;
    print "$tab$bot\n\n{$tab}Score: ";
}

multi sub squash (@c) { 
    my @t = grep { .chars }, @c;
    map { combine(@t[$_], @t[$_+1]) if @t[$_] && @t[$_+1] == @t[$_] }, ^@t-1;
    @t = grep { .chars }, @t;
    @t.push: '' while @t < 4;
    @t;
}

sub combine ($v is rw, $w is rw) { $v += $w; $w = ''; $score += $v; }

multi sub move('up') {
    map { @board[*]»[$_] = squash @board[*]»[$_] }, 0..3
}

multi sub move('down') {
    map { @board[*]»[$_] = reverse squash reverse @board[*]»[$_] }, 0..3
}

multi sub move('left') {
    map { @board[$_] = squash flat @board[$_]»[*] }, 0..3
}

multi sub move('right') {
    map { @board[$_] = reverse squash reverse flat @board[$_]»[*] }, 0..3
}

sub another {
    my @empties;
    for @board.kv -> $r, @row {
        @empties.push(($r, $_)) for @row.grep(:k, '');
    }
    my ( $x, $y ) = @empties.roll;
    @board[$x; $y] = (flat 2 xx 9, 4).roll;
}

loop {
   another if (join '|', flat @board».list) ne $save;
   draw-board;
   say $score;
   # Read up to 4 bytes from keyboard buffer.
   # Page navigation keys are 3-4 bytes each.
   # Specifically, arrow keys are 3.
   my $char = $*IN.read(4).decode.ords;
   $save = join '|', flat @board».list;
   move(%dir{$char}) if so %dir{$char};
   last if $char eq 113; # (q)uit
}
