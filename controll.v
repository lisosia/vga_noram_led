`define N 10
`define L 10
module controll(clk, rst, sum);
	parameter L = `L; parameter N = `N;
	input clk;
	input rst;
	output [L*N-1:0] sum;
	
	parameter INIT       = 4'h0,
			  DIV1       = 4'h1,
			  DIV2       = 4'h2,
			  SUB        = 4'h3,
			  DIV3       = 4'h4,
			  MERGEPLUS  = 4'h5,
  			  MERGEMINUS = 4'h6,
			  END        = 4'h7;
	reg [3:0] state;
	wire [9:0] initdiv1,initdiv2, constdiv1,constdiv2;
	assign initdiv1 = 10'd 80; //16*5
	assign initdiv2 = 10'd 956; //4*239
	assign constdiv1 = 10'd 25;
	assign constdiv2 = 10'd 239;

	reg [ 7:0 ] count; // count 0 ~~ L //!

	parameter NTIMES = 20; // 100/1.4 +1 ???   OVERFLOOOOOOOOOOOOOOOOOOOOOO!!!
	//wire[N-1:0] sumo,div1o, div2o, subo;
	//wire[ 7:0 ] sums,div1s,div2s,subs;
	reg [L*N-1:0] sum; //seldigit sumsel(sum ,sums, sumo);
	reg [L*N-1:0] div1;//seldigit div1sel(div1 ,div1s, div1o);
	reg [L*N-1:0] div2;//seldigit div2sel(div2 ,div2s, div2o);
	reg [L*N-1:0] sub; //seldigit subsel(sub ,subs, subo);
	
	wire [N-1:0] div1quo, div2quo;
	wire [10+N-1:0] div1rem, div2rem;
	reg [10+N-1:0] div1remm, div2remm;


	reg [N-1:0] div3valk;
	wire [N-1:0] param2k;
	assign param2k = div3valk * 2 - 1 ; //OVERFLOW AND DIE

	wire [N-1:0] div2Nbitn,div2Nbitd;
	// divider2(unit) is used at DIV1 and DIV3 ,input differs
	assign div2Nbitn = (state==DIV3) ? sub[N*count +:N] : div2[N*count +:N] ;
	assign div2Nbitd = (state==DIV3) ? param2k          : constdiv2;
	divider10a divider1 ( div1remm, div1[N*count +:N] , constdiv1, div1quo,div1rem );
	divider10a divider2 ( div2remm, div2Nbitn         , div2Nbitd, div2quo,div2rem );

	reg  subcin;
	wire subcoutw;
	wire [N-1:0] subNbita,subNbitb, subq;
	assign subNbita = (state==SUB) ? div1[N*count +:N]: sum[N*count +:N];
	assign subNbitb = (state==SUB) ? div2[N*count +:N]: sub[N*count +:N];
	sub10bitD subsracter( subNbita,subNbitb, subq, subcin,subcoutw  );

	// only used at MERGE
	reg addcin;
	wire addcoutw;
	wire [N-1:0] addq;
	add10bitD adder10D( sum[N*count +:N],sub[N*count +:N], addq, addcin,addcoutw );

	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			// reset
			// note: [MSB:LSB], calc MSB->LSB whe div, LSB->MSB when sub/add
			// 2.5 -> [<2>,<.5>, ...]
			sum <= { (N*L){1'b0} };
			div3valk <= 10'd 0;
			div1 <= { initdiv1,{(N*L-10){1'b0}} }; div1remm <= 0;
			div2 <= { initdiv2,{(N*L-10){1'b0}} }; div2remm <= 0;

			count <= L-1; state <= DIV1; //TODO
		end
		else begin
			case(state)

			DIV1: begin // div1 /= divider1, div2 /= divider2, ct:L-1->0
				div1[N*count +:N] <= div1quo; div1remm <= div1rem;
				div2[N*count +:N] <= div2quo; div2remm <= div2rem;
				if(count != 0) begin
					count <= count-1;
				end else begin
					count <= L-1;
					state <= DIV2; div1remm<=0;div2remm<=0;
				end
			end

			DIV2: begin // div2 /= divider2, ct:L-1->0
				div2[N*count +:N] <= div2quo; div2remm <= div2rem;
				if(count != 0) begin
					count <= count-1;
				end else begin
					count <= 0;
					state <= SUB; subcin <= 0;	
				end
			end

			SUB: begin // sub <- div1- div2, ct:0->L-1
				sub[N*count +:N] <= subq; subcin <= subcoutw;				
				if(count != L-1) begin
					count <= count +1;
				end else begin
					count <= L-1;
					div3valk <= div3valk +1;
					state <= DIV3; div1remm<=0;div2remm<=0;
				end
			end

			DIV3: begin // sub /= 2*k-1, ct:L-1->0
			//! TODO
				sub[N*count +:N] <= div2quo; div2remm <= div2rem;

				if(count != 0) begin
					count <= count-1;
				end else begin
					count <= L-1;
					//state <= (div3valk[0] == 1'b0) ? MERGEMINUS : MERGEPLUS;					
					if ( (div3valk[0]) == 0) begin
						state <= MERGEMINUS; count <=0; subcin<=0;
					end else begin
						state <= MERGEPLUS;  count <=0; addcin<=0;
					end
				end
			end

			MERGEPLUS: begin // sum <- sum + sub
				sum[N*count +:N] <= addq; addcin <= addcoutw;				
				if(count != L-1) begin
					count <= count +1;
				end else begin
					if(div3valk == NTIMES)begin
						state <= END;						
					end else begin
						count <= L-1; state <= DIV1; div1remm<=0;div2remm<=0;				
					end
				end
			end

			MERGEMINUS: begin // sum <- sum - sub
				sum[N*count +:N] <= subq; subcin <= subcoutw;				
				if(count != L-1) begin
					count <= count +1;
				end else begin
					if(div3valk == NTIMES)begin
						state <= END;
					end else begin
						count <= L-1; state <= DIV1; div1remm<=0;div2remm<=0;
					end
				end
			end

			END: begin
				//! TODO
			end
			endcase
		end
	end

endmodule

module seldigit(in, sel, out); //select digit[10bit]
	parameter L = 100, N = 10;
	input [L*N-1:0] in;
	input [ 7:0 ] sel;
	output [N-1:0] out;
	assign out = in[ N*(sel) +: N ];
endmodule
