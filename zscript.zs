version "4.8.0"

class ShootingRangeHandler : EventHandler
{
	override void NetworkProcess(consoleEvent e)
	{
		if (e.name ~== "summonTargetDummy")
		{
			let pmo = players[e.player].mo;
			if (!pmo)
				return;
			
			let dum = Actor.Spawn("ShootingRangeDummy", pmo.pos);
			if (dum)
			{
				dum.Warp(pmo, pmo.radius + dum.radius, 0, 0);
				if (e.args[0] != 0)
				{
					console.printf("Dummy angle: %f | Angle to player: %f", dum.angle, dum.AngleTo(pmo));
					dum.angle = pmo.angle + 180;
				}
			}
		}
	}
}

class ShootingRangeDummy : Actor
{
	const DAMPING = 0.032;
	const PI = 3.14159;
    int receivedDmg;
    int dmgStaggerTime;
    string inf;
    string src;
	double pitchangVel;
	double pitchang;
	double rollangVel;
	double rollang;
	double hitDir;
	double hitangle;
	vector3 dmgpos;

	Default
	{
		+ISMONSTER
		+SHOOTABLE
		+SOLID
		+DONTTHRUST
		+NOTIMEFREEZE
		+NODAMAGE
		+NOBLOOD
		Radius 20;
		Height 56;
	}

	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampIt = false)
	{
		double d = (val - source_min) * (out_max - out_min) / (source_max - source_min) + out_min;
		if (clampit)
		{
			double truemax = out_max > out_min ? out_max : out_min;
			double truemin = out_max > out_min ? out_min : out_max;
			d = Clamp(d, truemin, truemax);
		}
		return d;
	}

	void StartSwing(int damage)
	{
		double swingSpeed = Clamp(damage * 0.006, -0.5, 0.5);				
		double pitchFacFront = LinearMap(abs(hitangle), 0, 90, -1., 0., true);
		double pitchFacBack = LinearMap(abs(hitangle), 90, 180, 0., 1., true);
		pitchangVel = (swingspeed * swingSpeed * pitchFacFront) + (swingspeed * swingSpeed * pitchFacBack);
		double rollFacFront = LinearMap(hitangle, 0, -90, 0, -1., true);
		double rollFacBack = LinearMap(hitangle, 0, 90, 0, 1., true);
		rollangVel = (swingspeed * swingSpeed * rollFacFront) + (swingspeed * swingSpeed * rollFacBack);
	}

	void SpawnDamageNumbers(int damage)
	{
		string dmgstring = String.Format("%d", damage);
		int len = dmgstring.CodePointCount();
		for (int i = 0; i < len; i++)
		{
			let dnum = Spawn("DamageNumber", dmgpos);
			if (dnum)
			{
				dnum.A_SpriteOffset(i * 8 * dnum.scale.x);
				//string thisnum = dmgstring.Mid(i, 1);
				dnum.frame = dmgstring.ByteAt(i) - int("0");// thisnum.ToInt();
			}
		}
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		inf = inflictor ? inflictor.GetTag() : "unknown";
		src = source ?  source.GetTag() : "unknown";

        receivedDmg += damage;
		hitangle = AngleTo(inflictor ? inflictor : source);
        dmgStaggerTime = 1;

		dmgpos = pos + (0,0,height * 0.5);
		if (inflictor && inflictor != source)
		{
			let diff = Level.Vec2Diff(dmgpos.xy, inflictor.pos.xy);
			let dir = diff.unit();
			dmgpos.xy += (dir * radius * 0.75);
			dmgpos.z = inflictor.pos.z;
		}

		return super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
	}

    override void Tick()
    {        
        super.Tick();

        if (dmgStaggerTime > 0)
        {
            dmgStaggerTime--;
            if (dmgStaggerTime <= 0)
            {
		        console.printf("\c[Green]Target dummy received \c[Red]%d damage\c[Green] from \c[Cyan]%s\c[Green] (source: \c[Cyan]%s\c[Green])", receivedDmg, inf, src);
				SpawnDamageNumbers(receivedDmg);
				StartSwing(receivedDmg);
				
                if (receivedDmg > 15)
                    A_StartSound("targetdummy/pain", CHAN_BODY, CHANF_NOSTOP);
                receivedDmg = 0;
            }
        }

		pitchang = Clamp(pitchang += pitchangVel, -1.5, 1.5);
		pitchangVel += -(DAMPING * pitchang) - pitchangVel*DAMPING;
		pitch = pitchang * 180.0 / PI;
		rollang = Clamp(rollang += rollangVel, -1.2, 1.2);
		rollangVel += -(DAMPING * rollang) - rollangVel*DAMPING;
		roll = rollang * 180.0 / PI;
    }

	States {
	Spawn:
		AMRK A -1;
		stop;
	}
}

class DamageNumber : Actor
{
	Default
	{
		+NOBLOCKMAP
		scale 1.5;
	}

	override void Tick()
	{
		SetZ(pos.z+0.5);
		if (GetAge() > 25)
			A_FadeOut(0.05);
	}
	
	States {
	Spawn:
		TDNU A -1;
		stop;
	}
}