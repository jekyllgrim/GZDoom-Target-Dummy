version "4.10"

class ShootingRangeHandler : EventHandler
{
	override void NetworkProcess(consoleEvent e)
	{
		string name = e.name.MakeLower();
		if (name == 'summondummy' || name.IndexOf('summondummy') >= 0)
		{
			let pmo = players[e.player].mo;
			if (!pmo)
				return;
			
			let dum = ShootingRangeDummy(Actor.Spawn("ShootingRangeDummy", pmo.pos));
			if (dum)
			{
				dum.Warp(pmo, pmo.radius + dum.radius, 0, 0);
				dum.angle = pmo.angle + 180;
				array<string> cmdstring;
				e.name.Split(cmdstring, ":");
				if (cmdstring.Size() == 2)
				{
					dum.ApplyClassStyle(cmdstring[1]);
				}
			}
		}
	}
}

class ShootingRangeDummy : Actor
{
	const DAMPING = 0.032;
	const PI = 3.14159;
	class<Actor> prevInflictor;
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
	double basepitch;
	int classhealth;
	state spriteMainState;
	state spriteDeathState;	
	int deadtics;

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
		Mass 100;
		painsound "targetdummy/pain";
		painchance 96;
		Tag "Target dummy";		
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

	void ApplyClassStyle(name classname)
	{
		class<Actor> cls = classname;
		if (!cls)
		{
			console.printf("%s is not a valid class name. Reverting to default dummy model.", classname);
			return;
		}
		
		let def = GetDefaultByType(cls);

		if (!def.bISMONSTER)
		{
			console.printf("%s is not a monster class name. Reverting to default dummy model.", classname);
			return;
		}

		if (def)
		{
			spriteMainState = def.FindState("Missile");
			if (!spriteMainState)
				spriteMainState = def.FindState("Melee");
			if (!spriteMainState)
				spriteMainState = def.spawnstate;
			if (!spriteMainState)
			{
				console.printf("%s class does not have a valid Missile, Melee or Spawn state. Reverting to default dummy model.", classname);
				return;
			}
			sprite = spriteMainState.sprite;
			frame = spriteMainState.frame;
			bFLATSPRITE = true;

			let dstate = def.FindState("Death");
			while (dstate)
			{
				if (!dstate.nextstate || dstate.tics == -1)
				{
					spriteDeathState = dstate;
					break;
				}
				dstate = dstate.nextstate;
			}

			A_SetTranslation("WoodenTranslation");
			SetTag(String.Format("%s %s", def.GetTag(), "target dummy"));
			classhealth = def.GetMaxHealth();
			health = def.GetMaxHealth();
			A_SetSize(def.radius, def.height);
			scale = def.scale;

			/*A_ChangeModel("", flags: CMDL_HIDEMODEL);
			TextureID frontTex = st.GetSpriteTexture(1);			
			name frontTexName = TexMan.GetName(frontTex);
			double frontTexX, frontTexY;
			[frontTexX, frontTexY] = TexMan.GetSize(frontTex);
			A_ChangeModel("", 1, skinIndex: 1, skin: frontTexName);
			frontTex = st.GetSpriteTexture(8);			
			frontTexName = TexMan.GetName(frontTex);
			[frontTexX, frontTexY] = TexMan.GetSize(frontTex);
			A_ChangeModel("FlexibleDummy", modelPath: "models/dummy", model: "flexibleDummy.obj", skinIndex: 1, skin: frontTexName, flags: CMDL_USESURFACESKIN);
			scale = (frontTexX, frontTexY);*/

			bNORADIUSDMG = def.bNORADIUSDMG;
			bBOSS = def.bBOSS;
			mass = def.mass;
			painchance = def.painchance;
			painsound = def.painsound;
			deathsound = def.deathsound;
		}
	}

	void StartSwing(int damage)
	{
		double swingSpeed = Clamp(damage * 0.006, -0.5, 0.5) * LinearMap(mass, 100, 1000, 1, 0.1, true);	
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
				if (!bSHOOTABLE)
				{
					dnum.scale.y *= 1.2;
				}		
			}
		}
	}

	void ReportDamage()
	{
		string died;
		if (bFLATSPRITE && classhealth <= 0)
		{
			died = " \c[Red]and died";
			A_StartSound(deathsound, CHAN_BODY, CHANF_NOSTOP);
			classhealth = health;
			bSHOOTABLE = false;
			sprite = spriteDeathState.sprite;
			frame = spriteDeathState.frame;
			deadtics = 70;
		}
		else
		{
			StartSwing(receivedDmg);
			//if (receivedDmg > 15)
			//	A_StartSound(painsound, CHAN_BODY, CHANF_NOSTOP);
		}
		SpawnDamageNumbers(receivedDmg);

		console.printfEx(PRINT_NOLOG, "\c[Green]%s received \c[Red]%d damage\c[Green] from \c[Cyan]%s\c[Green] (source: \c[Cyan]%s\c[Green])%s", GetTag(), receivedDmg, inf, src, died);
		receivedDmg = 0;
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		inf = inflictor ? inflictor.GetTag() : "something";
		src = source ?  source.GetTag() : "unknown";

		if (inflictor && flags & DMG_EXPLOSION)
		{
			inf = String.Format("an explosive %s", inf);
		}

		Actor trueInflictor = inflictor ? inflictor : source ? source : null;

		receivedDmg += damage;
		if (classhealth > 0)
			classhealth -= damage;
		
		if (random[simpainch](1, 256) <= painchance)
			A_StartSound(painsound, CHAN_BODY, CHANF_NOSTOP);

		if (trueInflictor)
		{
			hitangle = DeltaAngle(self.angle, AngleTo(trueInflictor));
			dmgpos = pos + (0,0,height * 0.5);

			if (trueInflictor != source)
			{
				let diff = Level.Vec2Diff(dmgpos.xy, inflictor.pos.xy);
				let dir = diff.unit();
				dmgpos.xy += (dir * radius * 0.75);
				dmgpos.z = inflictor.pos.z;
			}

			if (flags & DMG_EXPLOSION)
			{
				ReportDamage();
			}
			else if (!prevInflictor || trueInflictor.GetClass() != prevInflictor)
			{
				ReportDamage();
				prevInflictor = trueInflictor.GetClass();
			}
			else
			{
				dmgStaggerTime = 1;
			}
		}
		else
		{
			ReportDamage();
			prevInflictor = null;
		}

		return super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		angle = Normalize180(angle);
	}

	override void Tick()
	{
		super.Tick();

		if (deadtics > 0)
		{
			deadtics--;
			if (deadtics == 0)
			{
				bSHOOTABLE = true;
				sprite = spriteMainState.sprite;
				frame = spriteMainState.frame;
			}
		}

		if (dmgStaggerTime > 0)
		{
			dmgStaggerTime--;
			if (dmgStaggerTime <= 0 && receivedDmg > 0)
			{
				ReportDamage();
			}
		}

		pitchang = Clamp(pitchang += pitchangVel, -1.5, 1.5);
		pitchangVel += -(DAMPING * pitchang) - pitchangVel*DAMPING;
		pitch = pitchang * 180.0 / PI - (bFLATSPRITE ? 90 : 0);
		rollang = Clamp(rollang += rollangVel, -1.2, 1.2);
		rollangVel += -(DAMPING * rollang) - rollangVel*DAMPING;
		roll = rollang * 180.0 / PI * (bFLATSPRITE ? -1 : 1);
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
		SetZ(pos.z+0.75);
		if (GetAge() > 25)
			A_FadeOut(0.05);
	}
	
	States {
	Spawn:
		TDNU A -1;
		stop;
	}
}